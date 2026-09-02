using System.Drawing;
using System.Windows.Forms;
using WindowControl.Config;
using WindowControl.Hooks;
using WindowControl.WindowOps;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.UI;

/// <summary>
/// Composition root: owns the keyboard/mouse hooks, the tray icon, the
/// config-driven action registry, and the small bit of drag-state that ties
/// a button-down to the button-up that ends it. This is the closest analogue
/// to the original script's auto-execute section plus its ~Alt:: dispatcher.
/// </summary>
internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly KeyboardHook _keyboard = new();
    private readonly MouseHook _mouse = new();
    private readonly WindowController _controller = new();
    private readonly ActionRegistry _registry;
    private readonly NotifyIcon _trayIcon;
    private readonly ToolStripMenuItem _pauseMenuItem;

    // Rebuilt after every settings save; maps a hotkey to whichever enabled
    // action currently claims it. Config-driven actions (the legacy-ini port
    // plus the numpad remaps) dispatch through here. The three hotkeys that
    // predate this system (rename, control-info, pause) stay hardcoded below
    // since they need cursor position rather than a resolved target window.
    private Dictionary<HotkeyCombo, ActionDefinition> _hotkeyMap = new();

    // Invisible, never-shown form that exists purely so hook callbacks can
    // marshal work onto the UI thread via BeginInvoke. Low-level hooks run
    // on the installing thread and Windows enforces a timeout (~300ms by
    // default) on how long a hook callback may block -- showing a modal
    // dialog or the clipboard call directly from the callback risks Windows
    // silently deciding the hook is unresponsive. Posting via BeginInvoke
    // lets the callback return immediately and do the real work on the next
    // message loop iteration instead.
    private readonly Form _syncForm;

    private enum DragMode { None, Move, Resize }
    private DragMode _dragMode = DragMode.None;
    private nint _dragTarget;
    private RECT _dragStartRect;
    private int _dragStartCursorX;
    private int _dragStartCursorY;
    private bool _dragLockPrimary;   // Ctrl:  locks X (move) / width (resize)
    private bool _dragLockSecondary; // Shift: locks Y (move) / height (resize)

    // The main (non-modifier) key of whichever combo we last dispatched on
    // key-down, so its key-up can be swallowed reliably. Re-matching the full
    // combo (including modifiers) at key-up time is fragile, since modifiers
    // are often released in a different order than they were pressed.
    private int? _lastDispatchedVk;

    private bool _hooksPaused;

    public TrayApplicationContext()
    {
        _syncForm = new Form
        {
            ShowInTaskbar = false,
            FormBorderStyle = FormBorderStyle.None,
            Width = 0,
            Height = 0,
            Opacity = 0,
            StartPosition = FormStartPosition.Manual,
            Location = new Point(-2000, -2000),
        };
        _ = _syncForm.Handle; // force native handle creation now, so BeginInvoke works immediately

        _registry = new ActionRegistry(_controller, OpenSettings, ExitApp, ShowQuickMenu);
        ConfigStore.Load(_registry.Actions);

        _pauseMenuItem = new ToolStripMenuItem("Pause", null, (_, _) => TogglePause());
        var settingsItem = new ToolStripMenuItem("Settings...", null, (_, _) => OpenSettings());
        var exitItem = new ToolStripMenuItem("Exit", null, (_, _) => ExitApp());
        var menu = new ContextMenuStrip();
        menu.Items.Add(settingsItem);
        menu.Items.Add(_pauseMenuItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(exitItem);

        _trayIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Visible = true,
            Text = "Window Control",
            ContextMenuStrip = menu,
        };

        WireHooks();
        RebuildHotkeyMap();
        _keyboard.Install();
        _mouse.Install();
    }

    private void WireHooks()
    {
        _mouse.LButtonDown += OnLButtonDown;
        _mouse.LButtonUp += OnLButtonUp;
        _mouse.RButtonDown += OnRButtonDown;
        _mouse.RButtonUp += OnRButtonUp;
        _mouse.MButtonDown += OnMButtonDown;
        _mouse.MouseMove += OnMouseMove;
        _keyboard.KeyDown += OnKeyDown;
        _keyboard.KeyUp += OnKeyUp;
    }

    // --- Mouse: Alt+LButton drag = move; Win+LButton = enable/disable ------

    private void OnLButtonDown(MouseEventArgsLL e)
    {
        if (_hooksPaused)
            return;

        if (_keyboard.AltDown && !_keyboard.WinDown && _dragMode == DragMode.None)
        {
            var hWnd = WindowController.WindowUnderPoint(e.X, e.Y);
            if (_controller.IsApprovedWindow(hWnd))
            {
                StartDrag(DragMode.Move, hWnd, e.X, e.Y,
                    lockPrimary: _keyboard.CtrlDown,     // Ctrl  = move along Y only
                    lockSecondary: _keyboard.ShiftDown); // Shift = move along X only
                e.Handled = true;
            }
        }
        else if (_keyboard.WinDown && !_keyboard.AltDown)
        {
            var hWnd = WindowController.WindowUnderPoint(e.X, e.Y);
            if (_controller.IsApprovedWindow(hWnd))
            {
                bool nowEnabled = _controller.ToggleEnabled(hWnd);
                ShowStatus(nowEnabled ? "Window Enabled!" : "Window Disabled!", e.X, e.Y);
                _keyboard.MarkWinConsumed();
                e.Handled = true;
            }
        }
    }

    private void OnLButtonUp(MouseEventArgsLL e)
    {
        if (_dragMode == DragMode.Move)
        {
            EndDrag();
            e.Handled = true;
        }
    }

    // --- Mouse: Alt+RButton drag = resize; Win+Ctrl+RButton = border toggle -

    private void OnRButtonDown(MouseEventArgsLL e)
    {
        if (_hooksPaused)
            return;

        if (_keyboard.AltDown && !_keyboard.WinDown && _dragMode == DragMode.None)
        {
            var hWnd = WindowController.WindowUnderPoint(e.X, e.Y);
            if (_controller.IsApprovedWindow(hWnd))
            {
                StartDrag(DragMode.Resize, hWnd, e.X, e.Y,
                    lockPrimary: _keyboard.CtrlDown,     // Ctrl  = resize height only
                    lockSecondary: _keyboard.ShiftDown); // Shift = resize width only
                e.Handled = true;
            }
        }
        else if (_keyboard.WinDown && _keyboard.CtrlDown)
        {
            var hWnd = WindowController.WindowUnderPoint(e.X, e.Y);
            if (_controller.IsApprovedWindow(hWnd))
            {
                bool hasBorder = _controller.ToggleBorder(hWnd);
                ShowStatus(hasBorder ? "Border Restored" : "Border Removed", e.X, e.Y);
                _keyboard.MarkWinConsumed();
                e.Handled = true;
            }
        }
        // Plain Win+RButton (no Ctrl) is left alone, same as the original script.
    }

    private void OnRButtonUp(MouseEventArgsLL e)
    {
        if (_dragMode == DragMode.Resize)
        {
            EndDrag();
            e.Handled = true;
        }
    }

    // --- Mouse: Alt+MButton = rename ---------------------------------------

    private void OnMButtonDown(MouseEventArgsLL e)
    {
        if (_hooksPaused || !_keyboard.AltDown)
            return;

        var hWnd = WindowController.WindowUnderPoint(e.X, e.Y);
        if (_controller.IsApprovedWindow(hWnd))
        {
            e.Handled = true;
            _syncForm.BeginInvoke(() => RenamePrompt(hWnd));
        }
    }

    // --- Mouse: drag tracking -----------------------------------------------

    private void OnMouseMove(MouseEventArgsLL e)
    {
        if (_dragMode == DragMode.None)
            return;

        if (!_keyboard.AltDown)
        {
            // Alt was released some other way (e.g. focus loss); bail out defensively.
            EndDrag();
            return;
        }

        int dx = e.X - _dragStartCursorX;
        int dy = e.Y - _dragStartCursorY;

        if (_dragMode == DragMode.Move)
        {
            int newX = _dragLockPrimary ? _dragStartRect.Left : _dragStartRect.Left + dx;
            int newY = _dragLockSecondary ? _dragStartRect.Top : _dragStartRect.Top + dy;
            _controller.Move(_dragTarget, newX, newY);
        }
        else
        {
            int newW = _dragLockPrimary ? _dragStartRect.Width : _dragStartRect.Width + dx;
            int newH = _dragLockSecondary ? _dragStartRect.Height : _dragStartRect.Height + dy;
            _controller.Resize(_dragTarget, newW, newH);
        }

        // Deliberately not setting e.Handled here: blocking WM_MOUSEMOVE in a
        // low-level mouse hook also freezes the on-screen cursor, since cursor
        // rendering is driven by the same input event this hook intercepts.
        // Blocking the button-down already stopped any native drag/selection
        // from starting, so letting move events continue through is safe.
    }

    private void StartDrag(DragMode mode, nint hWnd, int cursorX, int cursorY, bool lockPrimary, bool lockSecondary)
    {
        _dragMode = mode;
        _dragTarget = hWnd;
        _dragStartRect = WindowController.GetRect(hWnd);
        _dragStartCursorX = cursorX;
        _dragStartCursorY = cursorY;
        _dragLockPrimary = lockPrimary;
        _dragLockSecondary = lockSecondary;
    }

    private void EndDrag()
    {
        _dragMode = DragMode.None;
        _dragTarget = 0;
    }

    // --- Keyboard: Alt+Win+C = rename; Alt+Shift+C = copy control info;
    //     Win+Shift+S = pause/resume; everything else = the config-driven
    //     action registry (legacy-ini port + numpad remaps) --------------------

    private void OnKeyDown(KeyEventArgsLL e)
    {
        if (_hooksPaused && e.VirtualKeyCode != VK_S)
            return;

        if (MatchesRenameCombo(e))
        {
            GetCursorPos(out var pt);
            var hWnd = WindowController.WindowUnderPoint(pt.X, pt.Y);
            if (_controller.IsApprovedWindow(hWnd))
            {
                e.Handled = true;
                _lastDispatchedVk = e.VirtualKeyCode;
                _keyboard.MarkWinConsumed();
                _syncForm.BeginInvoke(() => RenamePrompt(hWnd));
            }
            return;
        }

        if (MatchesControlInfoCombo(e))
        {
            GetCursorPos(out var pt);
            var info = WindowController.DescribeControlUnderCursor(pt.X, pt.Y);
            if (info != null)
            {
                e.Handled = true;
                _lastDispatchedVk = e.VirtualKeyCode;
                _syncForm.BeginInvoke(() =>
                {
                    Clipboard.SetText(info);
                    ShowStatus("Control info copied", pt.X, pt.Y);
                });
            }
            return;
        }

        if (MatchesPauseCombo(e))
        {
            e.Handled = true;
            _lastDispatchedVk = e.VirtualKeyCode;
            _keyboard.MarkWinConsumed();
            _syncForm.BeginInvoke(TogglePause);
            return;
        }

        var combo = new HotkeyCombo(e.Alt, e.Ctrl, e.Shift, e.Win, e.VirtualKeyCode);
        if (_hotkeyMap.TryGetValue(combo, out var action) && action.Enabled)
        {
            e.Handled = true;
            _lastDispatchedVk = e.VirtualKeyCode;
            if (combo.Win)
                _keyboard.MarkWinConsumed();
            DispatchAction(action);
        }
    }

    private void OnKeyUp(KeyEventArgsLL e)
    {
        if (_lastDispatchedVk == e.VirtualKeyCode)
        {
            e.Handled = true;
            _lastDispatchedVk = null;
        }
    }

    private static bool MatchesRenameCombo(KeyEventArgsLL e) =>
        e.VirtualKeyCode == VK_C && e.Alt && e.Win && !e.Ctrl && !e.Shift;

    private static bool MatchesControlInfoCombo(KeyEventArgsLL e) =>
        e.VirtualKeyCode == VK_C && e.Alt && e.Shift && !e.Ctrl && !e.Win;

    private static bool MatchesPauseCombo(KeyEventArgsLL e) =>
        e.VirtualKeyCode == VK_S && e.Win && e.Shift && !e.Alt && !e.Ctrl;

    /// <summary>
    /// Resolves the action's target (if any) and runs it. Window/Navigation/
    /// Remap actions are all fast, non-blocking Win32 calls, so they run
    /// inline; App actions may show a dialog (Settings) or a popup menu
    /// (Quick Menu), so those are marshaled off the hook thread like the
    /// mouse-driven actions above.
    /// </summary>
    private void DispatchAction(ActionDefinition action)
    {
        nint target = action.Target == ActionTarget.ForegroundWindow ? GetForegroundWindow() : 0;

        if (action.Category == ActionCategory.App)
            _syncForm.BeginInvoke(() => action.Execute(target));
        else
            action.Execute(target);
    }

    private void RebuildHotkeyMap()
    {
        var map = new Dictionary<HotkeyCombo, ActionDefinition>();
        foreach (var action in _registry.Actions)
        {
            if (action.Enabled && !action.Hotkey.IsEmpty && !map.ContainsKey(action.Hotkey))
                map[action.Hotkey] = action;
        }
        _hotkeyMap = map;
    }

    // --- Shared actions -------------------------------------------------------

    private void RenamePrompt(nint hWnd)
    {
        string current = WindowController.GetTitle(hWnd);
        using var dlg = new RenameDialog(current);
        if (dlg.ShowDialog() == DialogResult.OK)
            WindowController.SetTitle(hWnd, dlg.NewTitle);
    }

    private void ShowStatus(string text, int screenX, int screenY)
    {
        _syncForm.BeginInvoke(() => TransientTooltip.Show(text, screenX, screenY));
    }

    /// <summary>Popup menu of the currently-enabled Window actions, applied to the given target when clicked.</summary>
    private void ShowQuickMenu(nint hWnd)
    {
        var menu = new ContextMenuStrip();
        foreach (var action in _registry.Actions.Where(a => a.Category == ActionCategory.Window && a.Enabled))
            menu.Items.Add(action.DisplayName, null, (_, _) => action.Execute(hWnd));

        if (menu.Items.Count == 0)
            menu.Items.Add("(no window actions enabled)").Enabled = false;

        menu.Show(Cursor.Position);
    }

    private void OpenSettings()
    {
        using var form = new SettingsForm(_registry.Actions, _keyboard);
        if (form.ShowDialog() == DialogResult.OK)
        {
            ConfigStore.Save(_registry.Actions);
            RebuildHotkeyMap();
        }
        // On Cancel, SettingsForm has already reverted the shared action
        // objects to their pre-dialog state, so there's nothing to undo here.
    }

    private void TogglePause()
    {
        _hooksPaused = !_hooksPaused;
        _pauseMenuItem.Text = _hooksPaused ? "Resume" : "Pause";
        _trayIcon.Text = _hooksPaused ? "Window Control (paused)" : "Window Control";
        ShowStatus(_hooksPaused ? "Window Control paused" : "Window Control resumed",
            Cursor.Position.X, Cursor.Position.Y);
    }

    private void ExitApp()
    {
        _trayIcon.Visible = false;
        _keyboard.Dispose();
        _mouse.Dispose();
        _syncForm.Dispose();
        ExitThread();
    }
}
