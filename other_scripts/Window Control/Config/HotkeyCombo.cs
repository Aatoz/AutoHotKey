using System.Windows.Forms;

namespace WindowControl.Config;

/// <summary>
/// An immutable modifiers+key combination. Used both as a hotkey trigger and,
/// for the numpad remap actions, as the key combo to synthesize.
///
/// Deliberately not left/right-specific (unlike a few of the legacy ini's
/// entries, e.g. "LShift + LCtrl + LAlt + S") -- this app's hook only tracks
/// combined Alt/Ctrl/Shift/Win state, so "Ctrl" here matches either physical
/// Ctrl key. A handful of legacy defaults collided once side-specificity was
/// dropped; see ActionRegistry for how those were resolved.
/// </summary>
internal readonly record struct HotkeyCombo(bool Alt, bool Ctrl, bool Shift, bool Win, int VirtualKeyCode)
{
    public static readonly HotkeyCombo None = default;

    public bool IsEmpty => VirtualKeyCode == 0;

    public override string ToString()
    {
        if (IsEmpty)
            return "(none)";

        var parts = new List<string>(5);
        if (Ctrl) parts.Add("Ctrl");
        if (Alt) parts.Add("Alt");
        if (Shift) parts.Add("Shift");
        if (Win) parts.Add("Win");
        parts.Add(KeyName(VirtualKeyCode));
        return string.Join(" + ", parts);
    }

    private static string KeyName(int vk)
    {
        // System.Windows.Forms.Keys shares the same numeric values as the
        // Win32 VK_* constants, so it doubles as a ready-made name table
        // (PageUp, Left, D4, NumPad1, ...) without hand-rolling one.
        var keys = (Keys)vk;
        return Enum.IsDefined(keys) ? keys.ToString() : $"0x{vk:X2}";
    }
}
