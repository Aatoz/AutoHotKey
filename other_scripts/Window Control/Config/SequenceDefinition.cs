namespace WindowControl.Config;

/// <summary>One step in a Sequence: a window rect as a fraction (0..1) of the monitor's work area.</summary>
internal sealed record SequenceStep(double X, double Y, double Width, double Height);

/// <summary>
/// A user-defined, ordered list of window positions/sizes bound to one
/// hotkey -- the "Sequencing" feature from WinSplit Revolution. Pressing the
/// hotkey the first time applies Steps[0]; pressing it again (for the same
/// window) advances to the next step, wrapping around.
///
/// Unlike everything in ActionRegistry, Sequences aren't defined in code --
/// they're fully authored by the user (via SequenceManagerForm) and their
/// whole definition is persisted, not just an Enabled/Hotkey override.
/// </summary>
internal sealed class SequenceDefinition
{
    public required string Id { get; init; }
    public string DisplayName { get; set; } = "New Sequence";
    public HotkeyCombo Hotkey { get; set; }
    public bool Enabled { get; set; } = true;
    public List<SequenceStep> Steps { get; set; } = new();
}
