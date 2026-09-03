namespace WindowControl.Config;

/// <summary>Grouping shown in the settings UI and used for a couple of category-wide behaviors (e.g. Quick Menu only lists Window actions).</summary>
internal enum ActionCategory { Window, Navigation, Remap, App }

/// <summary>What Execute should be given as its target when the action fires.</summary>
internal enum ActionTarget
{
    /// <summary>No target window -- e.g. a remap or an app-level action.</summary>
    None,

    /// <summary>The foreground window at the moment the hotkey fires.</summary>
    ForegroundWindow,
}

/// <summary>
/// One configurable hotkey-triggered action. The built-in fields (Id,
/// DisplayName, Category, HelpText, DefaultHotkey, Target, Execute) are set
/// up once in ActionRegistry and never change; Hotkey and Enabled are the
/// user-configurable parts, loaded from and saved to ConfigStore.
/// </summary>
internal sealed class ActionDefinition
{
    public required string Id { get; init; }
    public required string DisplayName { get; init; }
    public required ActionCategory Category { get; init; }
    public required string HelpText { get; init; }
    public required HotkeyCombo DefaultHotkey { get; init; }
    public required ActionTarget Target { get; init; }

    /// <summary>hWnd is 0 when Target is None.</summary>
    public required Action<nint> Execute { get; init; }

    /// <summary>Whether this action ships enabled out of the box (see ActionRegistry for the handful that don't, and why).</summary>
    public bool EnabledByDefault { get; init; } = true;

    public HotkeyCombo Hotkey { get; set; }
    public bool Enabled { get; set; }
}
