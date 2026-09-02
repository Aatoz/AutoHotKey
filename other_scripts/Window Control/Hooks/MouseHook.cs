using System.Runtime.InteropServices;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.Hooks;

/// <summary>
/// Wraps a global WH_MOUSE_LL hook and raises .NET events for the button/move
/// messages the app cares about. Handlers can set e.Handled = true to swallow
/// the event system-wide (used while dragging, so the click doesn't also
/// land on the window underneath).
/// </summary>
public sealed class MouseHook : IDisposable
{
    private readonly HookProc _proc;
    private nint _hookHandle;

    public event Action<MouseEventArgsLL>? LButtonDown;
    public event Action<MouseEventArgsLL>? LButtonUp;
    public event Action<MouseEventArgsLL>? RButtonDown;
    public event Action<MouseEventArgsLL>? RButtonUp;
    public event Action<MouseEventArgsLL>? MButtonDown;
    public event Action<MouseEventArgsLL>? MouseMove;

    public MouseHook()
    {
        _proc = HookCallback;
    }

    public void Install()
    {
        using var curProcess = System.Diagnostics.Process.GetCurrentProcess();
        using var curModule = curProcess.MainModule!;
        _hookHandle = SetWindowsHookEx(WH_MOUSE_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        if (_hookHandle == 0)
            throw new InvalidOperationException("Failed to install the mouse hook.");
    }

    private nint HookCallback(int nCode, nint wParam, nint lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
            var args = new MouseEventArgsLL(data.pt.X, data.pt.Y);
            int msg = (int)wParam;

            switch (msg)
            {
                case WM_LBUTTONDOWN: LButtonDown?.Invoke(args); break;
                case WM_LBUTTONUP: LButtonUp?.Invoke(args); break;
                case WM_RBUTTONDOWN: RButtonDown?.Invoke(args); break;
                case WM_RBUTTONUP: RButtonUp?.Invoke(args); break;
                case WM_MBUTTONDOWN: MButtonDown?.Invoke(args); break;
                case WM_MOUSEMOVE: MouseMove?.Invoke(args); break;
            }

            if (args.Handled)
                return 1;
        }

        return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    public void Dispose()
    {
        if (_hookHandle != 0)
        {
            UnhookWindowsHookEx(_hookHandle);
            _hookHandle = 0;
        }
    }
}

public sealed class MouseEventArgsLL(int x, int y)
{
    public int X { get; } = x;
    public int Y { get; } = y;
    public bool Handled { get; set; }
}
