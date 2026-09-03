using System.Text.Json;

namespace WindowControl.Config;

internal sealed record SavedActionConfig(bool Enabled, HotkeyCombo Hotkey);

/// <summary>Root of what's persisted to config.json.</summary>
internal sealed class AppConfig
{
    public Dictionary<string, SavedActionConfig> Actions { get; set; } = new();
    public List<SequenceDefinition> Sequences { get; set; } = new();

    /// <summary>WinSplit-style opt-in: Minimize/Maximize hotkeys cycle through Minimize -> Maximize -> Restore instead of always doing the same thing.</summary>
    public bool CycleMinimizeMaximize { get; set; }
}

/// <summary>
/// Loads/saves the user's config as JSON under %AppData%. Built-in actions
/// (what they do, their category, help text) live in code (ActionRegistry)
/// and are never persisted -- only each one's Enabled/Hotkey override is.
/// Sequences are fully user-authored, so their whole definition is
/// persisted here instead.
/// </summary>
internal static class ConfigStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private static string ConfigPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "WindowControl", "config.json");

    public static AppConfig Load()
    {
        if (!File.Exists(ConfigPath))
            return new AppConfig();

        try
        {
            var json = File.ReadAllText(ConfigPath);
            return JsonSerializer.Deserialize<AppConfig>(json) ?? new AppConfig();
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            // Corrupt or unreadable config -- fall back to defaults rather than failing to start.
            return new AppConfig();
        }
    }

    /// <summary>Overlays the config's per-action overrides onto the registry's built-in actions.</summary>
    public static void ApplyActionOverrides(AppConfig config, IEnumerable<ActionDefinition> actions)
    {
        foreach (var action in actions)
        {
            action.Enabled = action.EnabledByDefault;
            action.Hotkey = action.DefaultHotkey;

            if (config.Actions.TryGetValue(action.Id, out var saved))
            {
                action.Enabled = saved.Enabled;
                action.Hotkey = saved.Hotkey;
            }
        }
    }

    public static void Save(AppConfig config, IEnumerable<ActionDefinition> actions)
    {
        config.Actions = actions.ToDictionary(a => a.Id, a => new SavedActionConfig(a.Enabled, a.Hotkey));
        Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath)!);
        File.WriteAllText(ConfigPath, JsonSerializer.Serialize(config, JsonOptions));
    }
}
