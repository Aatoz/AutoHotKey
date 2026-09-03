using System.Windows.Forms;

namespace WindowControl.Config;

/// <summary>
/// Seeded the first time the app runs (before any config.json exists).
/// Mirrors WinSplit Revolution's numpad-as-screen-matrix default (7=top-left,
/// 8=top, 9=top-right, 4=left, 5=center, 6=right, 1=bottom-left, 2=bottom,
/// 3=bottom-right), each with a small starter sequence -- fully editable
/// afterward via "Manage Sequences...".
/// </summary>
internal static class SequenceDefaults
{
    public static List<SequenceDefinition> Create() =>
    [
        Make("seq-bottom-left", "Bottom Left", Keys.NumPad1,
            (0, 0.5, 0.5, 0.5), (0, 0.5, 0.33, 0.5)),
        Make("seq-bottom", "Bottom", Keys.NumPad2,
            (0, 0.5, 1.0, 0.5), (0.25, 0.5, 0.5, 0.5)),
        Make("seq-bottom-right", "Bottom Right", Keys.NumPad3,
            (0.5, 0.5, 0.5, 0.5), (0.67, 0.5, 0.33, 0.5)),
        Make("seq-left", "Left", Keys.NumPad4,
            (0, 0, 0.5, 1.0), (0, 0, 0.33, 1.0)),
        Make("seq-center", "Center", Keys.NumPad5,
            (0.25, 0.25, 0.5, 0.5), (0.1, 0.1, 0.8, 0.8)),
        Make("seq-right", "Right", Keys.NumPad6,
            (0.5, 0, 0.5, 1.0), (0.67, 0, 0.33, 1.0)),
        Make("seq-top-left", "Top Left", Keys.NumPad7,
            (0, 0, 0.5, 0.5), (0, 0, 0.33, 0.5)),
        Make("seq-top", "Top", Keys.NumPad8,
            (0, 0, 1.0, 0.5), (0.25, 0, 0.5, 0.5)),
        Make("seq-top-right", "Top Right", Keys.NumPad9,
            (0.5, 0, 0.5, 0.5), (0.67, 0, 0.33, 0.5)),
    ];

    private static SequenceDefinition Make(string id, string name, Keys key, params (double X, double Y, double W, double H)[] steps) =>
        new()
        {
            Id = id,
            DisplayName = name,
            Hotkey = new HotkeyCombo(true, true, false, false, (int)key), // Ctrl+Alt+Numpad(N), matching WinSplit's default
            Enabled = true,
            Steps = steps.Select(s => new SequenceStep(s.X, s.Y, s.W, s.H)).ToList(),
        };
}
