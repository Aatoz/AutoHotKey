using System.Runtime.InteropServices;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.Hooks;

/// <summary>
/// Wraps a global WH_KEYBOARD_LL hook and tracks the live down/up state of
/// the modifier keys the app cares about (Alt, Ctrl, Shift, Win), so callers
/// don't need to poll GetAsyncKeyState.
/// </summary>
internal sealed class KeyboardHook : IDisposable
{
    private readonly HookProc _proc;
    private nint _hookHandle;

    public bool AltDown { get; private set; }
    public bool CtrlDown { get; private set; }
    public bool ShiftDown { get; private set; }
    public bool WinDown { get; private set; }

    private bool _suppressNextWinKeyUp;

    /// <summary>Raised on key-down. Set e.Handled = true to swallow the keystroke system-wide.</summary>
    public event Action<KeyEventArgsLL>? KeyDown;

    /// <summary>Raised on key-up. Set e.Handled = true to swallow the keystroke system-wide.</summary>
    public event Action<KeyEventArgsLL>? KeyUp;

    public KeyboardHook()
    {
        _proc = HookCallback;
    }

    /// <summary>
    /// Call this after handling any action that used Win as a modifier
    /// (whether triggered by a key combo or a mouse click). It causes the
    /// next Win key-up to be swallowed, so Explorer never sees a "plain tap"
    /// of the Win key and doesn't pop the Start menu.
    /// </summary>
    public void MarkWinConsumed() => _suppressNextWinKeyUp = true;

    public void Install()
    {
        using var curProcess = System.Diagnostics.Process.GetCurrentProcess();
        using var curModule = curProcess.MainModule!;
        _hookHandle = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        if (_hookHandle == 0)
            throw new InvalidOperationException("Failed to install the keyboard hook.");
    }

    private nint HookCallback(int nCode, nint wParam, nint lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
            int vk = (int)data.vkCode;
            bool isDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
            bool isUp = wParam == WM_KEYUP || wParam == WM_SYSKEYUP;

            UpdateModifierState(vk, isDown, isUp);

            if (isUp && (vk == VK_LWIN || vk == VK_RWIN) && _suppressNextWinKeyUp)
            {
                _suppressNextWinKeyUp = false;
                return 1;
            }

            bool handled = false;
            if (isDown)
            {
                var args = new KeyEventArgsLL(vk, AltDown, CtrlDown, ShiftDown, WinDown);
                KeyDown?.Invoke(args);
                handled = args.Handled;
            }
            else if (isUp)
            {
                var args = new KeyEventArgsLL(vk, AltDown, CtrlDown, ShiftDown, WinDown);
                KeyUp?.Invoke(args);
                handled = args.Handled;
            }

            if (handled)
                return 1;
        }

        return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private void UpdateModifierState(int vk, bool isDown, bool isUp)
    {
        if (!isDown && !isUp)
            return;

        switch (vk)
        {
            case VK_LMENU:
            case VK_RMENU:
            case VK_MENU:
                AltDown = isDown;
                break;
            case VK_LCONTROL:
            case VK_RCONTROL:
            case VK_CONTROL:
                CtrlDown = isDown;
                break;
            case VK_LSHIFT:
            case VK_RSHIFT:
            case VK_SHIFT:
                ShiftDown = isDown;
                break;
            case VK_LWIN:
            case VK_RWIN:
                WinDown = isDown;
                if (isDown)
                    _suppressNextWinKeyUp = false;
                break;
        }
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

internal sealed class KeyEventArgsLL(int vk, bool alt, bool ctrl, bool shift, bool win)
{
    public int VirtualKeyCode { get; } = vk;
    public bool Alt { get; } = alt;
    public bool Ctrl { get; } = ctrl;
    public bool Shift { get; } = shift;
    public bool Win { get; } = win;
    public bool Handled { get; set; }
}
