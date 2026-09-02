using System.Windows.Forms;
using WindowControl.WindowOps;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.Config;

/// <summary>
/// Builds the full list of configurable actions -- ported from the legacy
/// ini's hotkeys, plus the Win+Numpad(N) remap. This is the single place
/// that knows what actions exist and what they default to; ConfigStore only
/// overlays the user's saved Enabled/Hotkey choices on top of what's built
/// here, and the settings UI edits those same two fields.
///
/// A few legacy defaults collide once left/right-specific modifiers are
/// generalized to plain Alt/Ctrl/Shift/Win (this app's hook doesn't track
/// which physical side was pressed). Rather than invent new default keys,
/// the loser of each collision ships disabled -- its historical hotkey is
/// still shown in the settings UI, just not live until you enable it (and
/// probably rebind it first). Each is called out below.
/// </summary>
internal sealed class ActionRegistry
{
    public IReadOnlyList<ActionDefinition> Actions { get; }

    public ActionRegistry(
        WindowController controller,
        Action openSettings,
        Action quitApp,
        Action<nint> showQuickMenu)
    {
        var list = new List<ActionDefinition>();

        // ---- Window: close ---------------------------------------------------

        list.Add(Window("close-window", "Close Window",
            "Closes the focused window.",
            H(alt: true, key: Keys.F4),
            hWnd => WindowController.Close(hWnd)));

        list.Add(Window("close-all-windows", "Close All Windows",
            "Closes every window.",
            H(ctrl: true, alt: true, key: Keys.C),
            _ => controller.CloseAllWindows(),
            enabledByDefault: false)); // Off by default: destructive, and collides
                                       // with Resize To Center Three-Fourths.

        list.Add(Window("close-all-but-current", "Close All But Current Window",
            "Closes every other window.",
            H(ctrl: true, alt: true, shift: true, key: Keys.C),
            hWnd => controller.CloseAllExcept(hWnd),
            enabledByDefault: false)); // Off by default: destructive.

        // ---- Window: maximize / minimize --------------------------------------

        list.Add(Window("maximize-window", "Maximize Window",
            "Maximizes the focused window.",
            H(ctrl: true, alt: true, key: Keys.PageUp),
            hWnd => WindowController.Maximize(hWnd)));

        list.Add(Window("maximize-horizontally", "Maximize Horizontally",
            "Stretches the focused window to the full width of its monitor.",
            H(ctrl: true, alt: true, key: Keys.H),
            hWnd => controller.MaximizeHorizontally(hWnd)));

        list.Add(Window("maximize-vertically", "Maximize Vertically",
            "Stretches the focused window to the full height of its monitor.",
            H(ctrl: true, alt: true, key: Keys.V),
            hWnd => controller.MaximizeVertically(hWnd)));

        list.Add(Window("maximize-all-monitors", "Maximize Across All Monitors",
            "Maximizes the focused window across every monitor.",
            H(ctrl: true, shift: true, alt: true, key: Keys.PageUp),
            hWnd => controller.MaximizeAcrossAllMonitors(hWnd)));

        list.Add(Window("minimize-window", "Minimize Window",
            "Minimizes the focused window.",
            H(ctrl: true, alt: true, key: Keys.PageDown),
            hWnd => WindowController.Minimize(hWnd)));

        // ---- Window: half / quarter resize --------------------------------------

        list.Add(Window("resize-left-half", "Resize To Left Half",
            "Resizes the focused window to the left half of its monitor.",
            H(shift: true, ctrl: true, alt: true, key: Keys.A),
            hWnd => controller.ResizeToHalf(hWnd, Edge.Left)));

        list.Add(Window("resize-right-half", "Resize To Right Half",
            "Resizes the focused window to the right half of its monitor.",
            H(shift: true, ctrl: true, alt: true, key: Keys.D),
            hWnd => controller.ResizeToHalf(hWnd, Edge.Right)));

        list.Add(Window("resize-top-half", "Resize To Top Half",
            "Resizes the focused window to the top half of its monitor.",
            H(shift: true, ctrl: true, alt: true, key: Keys.W),
            hWnd => controller.ResizeToHalf(hWnd, Edge.Top)));

        list.Add(Window("resize-bottom-half", "Resize To Bottom Half",
            "Resizes the focused window to the bottom half of its monitor.",
            H(shift: true, ctrl: true, alt: true, key: Keys.S),
            hWnd => controller.ResizeToHalf(hWnd, Edge.Bottom)));

        list.Add(Window("resize-center-half", "Resize To Center Half",
            "Resizes the focused window to half the size of its monitor, centered.",
            H(ctrl: true, alt: true, key: Keys.Q),
            hWnd => controller.ResizeToCenterFraction(hWnd, 0.5)));

        list.Add(Window("resize-center-three-fourths", "Resize To Center Three-Fourths",
            "Resizes the focused window to three-fourths the size of its monitor, centered.",
            H(ctrl: true, alt: true, key: Keys.C),
            hWnd => controller.ResizeToCenterFraction(hWnd, 0.75)));

        // ---- Window: snap ---------------------------------------------------------

        list.Add(Window("snap-top-left", "Snap to Top Left",
            "Snaps the focused window to the top left corner of its monitor.",
            H(win: true, alt: true, key: Keys.Left),
            hWnd => controller.SnapToCorner(hWnd, Corner.TopLeft)));

        list.Add(Window("snap-top-right", "Snap to Top Right",
            "Snaps the focused window to the top right corner of its monitor.",
            H(win: true, alt: true, key: Keys.Right),
            hWnd => controller.SnapToCorner(hWnd, Corner.TopRight)));

        list.Add(Window("snap-bottom-left", "Snap to Bottom Left",
            "Snaps the focused window to the bottom left corner of its monitor.",
            H(win: true, ctrl: true, alt: true, key: Keys.Left),
            hWnd => controller.SnapToCorner(hWnd, Corner.BottomLeft)));

        list.Add(Window("snap-bottom-right", "Snap to Bottom Right",
            "Snaps the focused window to the bottom right corner of its monitor.",
            H(win: true, ctrl: true, alt: true, key: Keys.Right),
            hWnd => controller.SnapToCorner(hWnd, Corner.BottomRight)));

        // The legacy ini's "Snap to Corner Left/Right/Top/Bottom" turned out to
        // be single-axis alignment, not a resize: it moves the window flush
        // against one edge of the monitor -- e.g. "Left" sets X to the work
        // area's left edge -- while leaving the other axis and both
        // dimensions untouched. "Corner" was a misleading name for that, so
        // these are named/identified as "Edge" instead.
        list.Add(Window("snap-edge-left", "Snap to Left Edge",
            "Aligns the left edge of the focused window with its monitor's left edge, without resizing it.",
            H(win: true, ctrl: true, alt: true, key: Keys.L),
            hWnd => controller.SnapToEdge(hWnd, Edge.Left)));

        list.Add(Window("snap-edge-right", "Snap to Right Edge",
            "Aligns the right edge of the focused window with its monitor's right edge, without resizing it.",
            H(win: true, ctrl: true, alt: true, key: Keys.R),
            hWnd => controller.SnapToEdge(hWnd, Edge.Right)));

        list.Add(Window("snap-edge-top", "Snap to Top Edge",
            "Aligns the top edge of the focused window with its monitor's top edge, without resizing it.",
            H(win: true, ctrl: true, alt: true, key: Keys.Up),
            hWnd => controller.SnapToEdge(hWnd, Edge.Top)));

        list.Add(Window("snap-edge-bottom", "Snap to Bottom Edge",
            "Aligns the bottom edge of the focused window with its monitor's bottom edge, without resizing it.",
            H(win: true, ctrl: true, alt: true, key: Keys.Down),
            hWnd => controller.SnapToEdge(hWnd, Edge.Bottom)));

        list.Add(Window("snap-center", "Snap to Center",
            "Snaps the focused window to the center of its monitor.",
            H(win: true, ctrl: true, alt: true, key: Keys.C),
            hWnd => controller.SnapToCenter(hWnd)));

        list.Add(Window("snap-center-of-parent", "Snap to Center of Parent Window",
            "Snaps the focused window to the center of its owner window, or its monitor if it has none.",
            H(win: true, alt: true, key: Keys.C),
            hWnd => controller.SnapToCenterOfParent(hWnd),
            enabledByDefault: false)); // Off by default: collides with the existing
                                       // Alt+Win+C rename hotkey.

        // ---- Window: monitor / properties -----------------------------------------

        list.Add(Window("move-left-monitor", "Window To Left Monitor",
            "Moves the focused window to the monitor on the left (wraps around).",
            H(ctrl: true, alt: true, key: Keys.Left),
            hWnd => controller.MoveToMonitor(hWnd, MonitorDirection.Left)));

        list.Add(Window("move-right-monitor", "Window To Right Monitor",
            "Moves the focused window to the monitor on the right (wraps around).",
            H(ctrl: true, alt: true, key: Keys.Right),
            hWnd => controller.MoveToMonitor(hWnd, MonitorDirection.Right)));

        list.Add(Window("toggle-border", "Toggle Window Border",
            "Removes the focused window's border, or restores it.",
            H(shift: true, ctrl: true, alt: true, key: Keys.B),
            hWnd => controller.ToggleBorder(hWnd)));

        list.Add(Window("toggle-always-on-top", "Toggle Always On Top",
            "Makes the focused window always-on-top, or normal again.",
            H(ctrl: true, alt: true, key: Keys.O),
            hWnd => WindowController.ToggleAlwaysOnTop(hWnd)));

        list.Add(Window("transparency-increment", "Increment Transparency",
            "Makes the focused window more transparent.",
            H(win: true, alt: true, key: Keys.T),
            hWnd => WindowController.IncrementTransparency(hWnd)));

        list.Add(Window("transparency-decrement", "Decrement Transparency",
            "Makes the focused window more opaque.",
            H(win: true, shift: true, alt: true, key: Keys.T),
            hWnd => WindowController.DecrementTransparency(hWnd)));

        list.Add(Window("transparency-disable", "Disable Transparency",
            "Makes the focused window fully opaque.",
            H(win: true, shift: true, key: Keys.O),
            hWnd => WindowController.DisableTransparency(hWnd)));

        // ---- Navigation -------------------------------------------------------------

        list.Add(Nav("browser-back", "Browser Backward",
            "Goes back one page (also works in Explorer, not just browsers).",
            H(win: true, alt: true, key: Keys.Left),
            () => InputSimulator.Tap(VK_BROWSER_BACK),
            enabledByDefault: false)); // Off by default: collides with Snap to Top Left.

        list.Add(Nav("browser-forward", "Browser Forward",
            "Goes forward one page (also works in Explorer, not just browsers).",
            H(win: true, alt: true, key: Keys.Right),
            () => InputSimulator.Tap(VK_BROWSER_FORWARD),
            enabledByDefault: false)); // Off by default: collides with Snap to Top Right.

        list.Add(Nav("browser-refresh", "Browser Refresh",
            "Refreshes the page.",
            HotkeyCombo.None, // No default hotkey in the legacy ini either.
            () => InputSimulator.Tap(VK_BROWSER_REFRESH)));

        list.Add(Nav("browser-tab-backward", "Browser Tab Backward",
            "Switches to the previous tab (Ctrl+Shift+Tab) in the focused app.",
            H(alt: true, shift: true, key: Keys.Up),
            () => InputSimulator.Combo(VK_CONTROL, VK_SHIFT, VK_TAB)));

        list.Add(Nav("browser-tab-forward", "Browser Tab Forward",
            "Switches to the next tab (Ctrl+Tab) in the focused app.",
            H(alt: true, shift: true, key: Keys.Down),
            () => InputSimulator.Combo(VK_CONTROL, VK_TAB)));

        // ---- Remap: Win+Numpad(N) -> Win+(N), taskbar app launch/switch -----------

        for (int n = 1; n <= 9; n++)
        {
            int digit = n; // capture for the closure below
            list.Add(new ActionDefinition
            {
                Id = $"remap-numpad-{digit}",
                DisplayName = $"Remap Win+Numpad{digit} to Win+{digit}",
                Category = ActionCategory.Remap,
                HelpText = $"Pressing Win+Numpad{digit} does what Win+{digit} normally does " +
                           $"(switch to/launch the {Ordinal(digit)} taskbar app).",
                DefaultHotkey = H(win: true, key: NumpadKey(digit)),
                Target = ActionTarget.None,
                Execute = _ => InputSimulator.Tap(VK_0 + digit),
            });
        }

        // ---- App meta --------------------------------------------------------------

        list.Add(App("open-settings", "Activate App",
            "Opens this app's settings window.",
            H(ctrl: true, alt: true, key: Keys.D4),
            _ => openSettings()));

        list.Add(App("quit-application", "Quit Application",
            "Completely exits Window Control.",
            H(win: true, shift: true, key: Keys.Q),
            _ => quitApp()));

        list.Add(new ActionDefinition
        {
            Id = "quick-menu",
            DisplayName = "Quick Menu",
            Category = ActionCategory.App,
            HelpText = "Shows a menu of shortcuts for the most useful window actions, applied to the focused window.",
            DefaultHotkey = H(win: true, key: Keys.U),
            Target = ActionTarget.ForegroundWindow,
            Execute = hWnd => showQuickMenu(hWnd),
        });

        Actions = list;

        // TODO: Mosaic Mode (from the legacy ini, disabled there too) --
        // "Arranges windows of the same type into a logical arrangement."
        // Not implemented; needs design.
        //
        // TODO: Automatic Placement (from the legacy ini, disabled there
        // too) -- legacy description was empty. Not implemented; needs
        // design.
    }

    private static ActionDefinition Window(string id, string name, string help, HotkeyCombo hotkey, Action<nint> execute, bool enabledByDefault = true) =>
        new()
        {
            Id = id,
            DisplayName = name,
            Category = ActionCategory.Window,
            HelpText = help,
            DefaultHotkey = hotkey,
            Target = ActionTarget.ForegroundWindow,
            Execute = execute,
            EnabledByDefault = enabledByDefault,
        };

    private static ActionDefinition Nav(string id, string name, string help, HotkeyCombo hotkey, Action execute, bool enabledByDefault = true) =>
        new()
        {
            Id = id,
            DisplayName = name,
            Category = ActionCategory.Navigation,
            HelpText = help,
            DefaultHotkey = hotkey,
            Target = ActionTarget.None,
            Execute = _ => execute(),
            EnabledByDefault = enabledByDefault,
        };

    private static ActionDefinition App(string id, string name, string help, HotkeyCombo hotkey, Action<nint> execute, bool enabledByDefault = true) =>
        new()
        {
            Id = id,
            DisplayName = name,
            Category = ActionCategory.App,
            HelpText = help,
            DefaultHotkey = hotkey,
            Target = ActionTarget.None,
            Execute = execute,
            EnabledByDefault = enabledByDefault,
        };

    private static HotkeyCombo H(bool alt = false, bool ctrl = false, bool shift = false, bool win = false, Keys key = Keys.None) =>
        new(alt, ctrl, shift, win, (int)key);

    private static Keys NumpadKey(int digit) => digit switch
    {
        1 => Keys.NumPad1,
        2 => Keys.NumPad2,
        3 => Keys.NumPad3,
        4 => Keys.NumPad4,
        5 => Keys.NumPad5,
        6 => Keys.NumPad6,
        7 => Keys.NumPad7,
        8 => Keys.NumPad8,
        9 => Keys.NumPad9,
        _ => throw new ArgumentOutOfRangeException(nameof(digit)),
    };

    private static string Ordinal(int n) => n switch
    {
        1 => "1st",
        2 => "2nd",
        3 => "3rd",
        _ => $"{n}th",
    };
}
