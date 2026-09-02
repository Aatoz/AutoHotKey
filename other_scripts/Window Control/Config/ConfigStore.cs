using System.Text.Json;

namespace WindowControl.Config;

internal sealed record SavedActionConfig(bool Enabled, HotkeyCombo Hotkey);

/// <summary>
/// Loads/saves the user's per-action Enabled/Hotkey overrides as JSON under
/// %AppData%. Everything else about an action (what it does, its category,
/// its help text) lives in code (ActionRegistry) and is never persisted.
/// </summary>
internal static class ConfigStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    private static string ConfigPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "WindowControl", "config.json");

    /// <summary>Applies any saved overrides onto the given actions; actions with no saved entry keep their built-in defaults.</summary>
    public static void Load(IEnumerable<ActionDefinition> actions)
    {
        foreach (var action in actions)
        {
            action.Enabled = action.EnabledByDefault;
            action.Hotkey = action.DefaultHotkey;
        }

        if (!File.Exists(ConfigPath))
            return;

        try
        {
            var json = File.ReadAllText(ConfigPath);
            var saved = JsonSerializer.Deserialize<Dictionary<string, SavedActionConfig>>(json);
            if (saved == null)
                return;

            foreach (var action in actions)
            {
                if (saved.TryGetValue(action.Id, out var s))
                {
                    action.Enabled = s.Enabled;
                    action.Hotkey = s.Hotkey;
                }
            }
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            // Corrupt or unreadable config -- fall back to the built-in defaults
            // already applied above rather than failing to start.
        }
    }

    public static void Save(IEnumerable<ActionDefinition> actions)
    {
        var dict = actions.ToDictionary(a => a.Id, a => new SavedActionConfig(a.Enabled, a.Hotkey));
        Directory.CreateDirectory(Path.GetDirectoryName(ConfigPath)!);
        File.WriteAllText(ConfigPath, JsonSerializer.Serialize(dict, JsonOptions));
    }
}
