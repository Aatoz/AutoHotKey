using System.Runtime.InteropServices;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.WindowOps;

/// <summary>
/// Synthesizes keystrokes via SendInput. Used for actions that don't operate
/// on a target window at all -- browser back/forward/refresh, tab cycling,
/// and the Win+Numpad(N) -&gt; Win+(N) remaps -- so they reach whatever
/// currently has focus, the same way a real key press would.
/// </summary>
internal static class InputSimulator
{
    /// <summary>Presses and releases a single key, with no modifiers.</summary>
    public static void Tap(int vk) => Combo(vk);

    /// <summary>
    /// Presses the given keys down in order, then releases them in reverse
    /// order (so e.g. Combo(VK_CONTROL, VK_TAB) is a proper Ctrl+Tab chord).
    /// </summary>
    public static void Combo(params int[] vks)
    {
        if (vks.Length == 0)
            return;

        var events = new INPUT[vks.Length * 2];
        for (int i = 0; i < vks.Length; i++)
            events[i] = MakeKeyInput(vks[i], down: true);
        for (int i = 0; i < vks.Length; i++)
            events[vks.Length + i] = MakeKeyInput(vks[vks.Length - 1 - i], down: false);

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
}
