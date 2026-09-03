using Microsoft.Win32;

namespace WindowControl.UI;

/// <summary>
/// Reads Windows' current app light/dark theme from the registry, and
/// raises an event when the user changes it while the app is running.
/// </summary>
internal static class ThemeDetector
{
    private const string PersonalizeKey = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
    private const string ValueName = "AppsUseLightTheme";

    /// <summary>Raised when Windows' theme setting changes while the app is running.</summary>
    public static event Action? ThemeChanged;

    private static bool _subscribed;

    /// <summary>
    /// True for light theme, false for dark. Checks AppsUseLightTheme (how
    /// apps render themselves) rather than SystemUsesLightTheme (the
    /// taskbar/Start specifically) -- in practice Windows keeps these in
    /// sync for the overwhelming majority of configurations, and
    /// AppsUseLightTheme is the more commonly-referenced key for "does an
    /// app's own light/dark choice apply right now".
    /// </summary>
    public static bool IsLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(PersonalizeKey);
            if (key?.GetValue(ValueName) is int value)
                return value != 0;
        }
        catch (Exception ex) when (ex is System.Security.SecurityException or IOException or UnauthorizedAccessException)
        {
            // Fall through to the default below.
        }

        return true; // Windows itself defaults to light theme when this key is absent.
    }

    /// <summary>Starts listening for theme changes. Safe to call more than once -- only subscribes on the first call.</summary>
    public static void StartWatching()
    {
        if (_subscribed)
            return;

        _subscribed = true;
        SystemEvents.UserPreferenceChanged += (_, e) =>
        {
            if (e.Category == UserPreferenceCategory.General)
                ThemeChanged?.Invoke();
        };
    }
}
