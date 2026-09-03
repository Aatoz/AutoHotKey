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

    /// <summary>Raised on key-down. Set e.Handled = true to swallow the keystroke system-wide.</summary>
    public event Action<KeyEventArgsLL>? KeyDown;

    /// <summary>Raised on key-up. Set e.Handled = true to swallow the keystroke system-wide.</summary>
    public event Action<KeyEventArgsLL>? KeyUp;

    public KeyboardHook()
    {
        _proc = HookCallback;
    }

    public void Install()
    {
        using var curProcess = System.Diagnostics.Process.GetCurrentProcess();
        using var curModule = curProcess.MainModule!;
        _hookHandle = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        if (_hookHandle == 0)
            throw new InvalidOperationException("Failed to install the keyboard hook.");
    }

    /// <summary>
    /// Call this while Win (or Alt) is still physically held, right as you're
    /// about to consume it as a modifier for one of our own hotkeys or mouse
    /// combos. It injects a tap of an inert "no mapping" key (see
    /// VK_MASK_NONE), which makes Explorer see "another key was pressed
    /// while Win was held" and skip the Start Menu on release -- Win's own
    /// real down/up events are never touched.
    ///
    /// This replaces an earlier approach that instead blocked Win's own
    /// key-up message from reaching CallNextHookEx. That did stop the Start
    /// Menu, but it also meant no other listener -- other global hooks,
    /// AutoHotkey scripts, anything that tracks key state from actual
    /// messages rather than polling hardware -- ever saw Win's release,
    /// which is exactly what a "stuck key" looks like from their side.
    /// Injecting a masking key instead leaves every real key event alone, so
    /// nothing else can lose track of them.
    /// </summary>
    public static void SuppressMenuActivation()
    {
        var events = new[]
        {
            MakeKeyInput(VK_MASK_NONE, down: true),
            MakeKeyInput(VK_MASK_NONE, down: false),
        };
        SendInput((uint)events.Length, events, Marshal.SizeOf<INPUT>());
    }

    private static INPUT MakeKeyInput(int vk, bool down) => new()
    {
        type = INPUT_KEYBOARD,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = (ushort)vk,
                wScan = 0,
                dwFlags = down ? 0u : KEYEVENTF_KEYUP,
                time = 0,
                dwExtraInfo = 0,
            },
        },
    };

    private nint HookCallback(int nCode, nint wParam, nint lParam)
    {
        if (nCode >= 0)
        {
            var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

            // Don't process our own injected masking keystrokes as real
            // input -- just let them continue on to Explorer, which is the
            // only thing that actually needs to see them.
            if ((data.flags & LLKHF_INJECTED) != 0 && data.vkCode == VK_MASK_NONE)
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);

            int vk = (int)data.vkCode;
            bool isDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;
            bool isUp = wParam == WM_KEYUP || wParam == WM_SYSKEYUP;

            UpdateModifierState(vk, isDown, isUp);

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
