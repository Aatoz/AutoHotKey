using System.Drawing;
using System.Windows.Forms;
using WindowControl.Hooks;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.Config;

/// <summary>
/// Lets you enable/disable each action and rebind its hotkey. Recording a new
/// hotkey reuses the app's existing global KeyboardHook (rather than
/// WinForms' own KeyDown), since that's the only reliable way to capture
/// combos that include the Win key -- Explorer normally swallows Win-key
/// combos before ordinary window messages ever see them.
///
/// Known rough edge: while recording, the hotkey map that's already live is
/// still active, so pressing an existing bound combo will also fire that
/// action while you're capturing a new one.
/// </summary>
internal sealed class SettingsForm : Form
{
    private readonly IReadOnlyList<ActionDefinition> _actions;
    private readonly KeyboardHook _keyboard;
    private readonly AppConfig _appConfig;
    private readonly bool _originalCycleMinimizeMaximize;
    private readonly Dictionary<string, (bool Enabled, HotkeyCombo Hotkey)> _snapshot = new();

    private readonly ListView _list;
    private readonly Button _recordButton;
    private readonly Button _resetButton;
    private readonly CheckBox _cycleMinMaxCheckBox;
    private readonly Label _statusLabel;

    private ActionDefinition? Selected =>
        _list.SelectedItems.Count > 0 ? (ActionDefinition)_list.SelectedItems[0].Tag! : null;

    public SettingsForm(IReadOnlyList<ActionDefinition> actions, KeyboardHook keyboard, AppConfig appConfig, Action manageSequences)
    {
        _actions = actions;
        _keyboard = keyboard;
        _appConfig = appConfig;
        _originalCycleMinimizeMaximize = appConfig.CycleMinimizeMaximize;

        Text = "Window Control Settings";
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        ClientSize = new Size(720, 560);
        MinimumSize = new Size(560, 400);

        _list = new ListView
        {
            View = View.Details,
            FullRowSelect = true,
            GridLines = true,
            CheckBoxes = true,
            ShowItemToolTips = true,
            Dock = DockStyle.Fill,
        };
        _list.Columns.Add("Action", 320);
        _list.Columns.Add("Category", 100);
        _list.Columns.Add("Hotkey", 220);
        _list.ItemChecked += (_, e) => ((ActionDefinition)e.Item!.Tag!).Enabled = e.Item.Checked;
        _list.SelectedIndexChanged += (_, _) =>
        {
            _recordButton.Enabled = Selected != null;
            _resetButton.Enabled = Selected != null;
        };

        foreach (var action in actions.OrderBy(a => a.Category).ThenBy(a => a.DisplayName))
        {
            _snapshot[action.Id] = (action.Enabled, action.Hotkey);
            var item = new ListViewItem(action.DisplayName) { Tag = action, Checked = action.Enabled, ToolTipText = action.HelpText };
            item.SubItems.Add(action.Category.ToString());
            item.SubItems.Add(action.Hotkey.ToString());
            _list.Items.Add(item);
        }

        _statusLabel = new Label
        {
            Dock = DockStyle.Top,
            Height = 24,
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(4, 0, 0, 0),
        };

        _recordButton = new Button { Text = "Change Hotkey...", Enabled = false, AutoSize = true };
        _recordButton.Click += OnRecordClick;

        _resetButton = new Button { Text = "Reset to Default", Enabled = false, AutoSize = true };
        _resetButton.Click += OnResetClick;

        var okButton = new Button { Text = "OK", DialogResult = DialogResult.OK, AutoSize = true };
        okButton.Click += OnOkClick;

        var cancelButton = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        cancelButton.Click += (_, _) =>
        {
            RevertToSnapshot();
            _appConfig.CycleMinimizeMaximize = _originalCycleMinimizeMaximize;
        };

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            FlowDirection = FlowDirection.RightToLeft,
            Height = 44,
            Padding = new Padding(8),
        };
        buttonPanel.Controls.Add(cancelButton);
        buttonPanel.Controls.Add(okButton);
        buttonPanel.Controls.Add(_resetButton);
        buttonPanel.Controls.Add(_recordButton);

        var sequencesButton = new Button { Text = "Manage Sequences...", AutoSize = true };
        sequencesButton.Click += (_, _) => manageSequences();

        _cycleMinMaxCheckBox = new CheckBox
        {
            Text = "Minimize/Maximize hotkeys cycle through states (Minimize \u2192 Maximize \u2192 Restore)",
            AutoSize = true,
            Checked = appConfig.CycleMinimizeMaximize,
        };
        _cycleMinMaxCheckBox.CheckedChanged += (_, _) => _appConfig.CycleMinimizeMaximize = _cycleMinMaxCheckBox.Checked;

        var optionsPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            FlowDirection = FlowDirection.LeftToRight,
            Height = 36,
            Padding = new Padding(8, 6, 8, 0),
        };
        optionsPanel.Controls.Add(sequencesButton);
        optionsPanel.Controls.Add(_cycleMinMaxCheckBox);

        Controls.Add(_list);
        Controls.Add(buttonPanel);
        Controls.Add(optionsPanel);
        Controls.Add(_statusLabel);

        AcceptButton = okButton;
        CancelButton = cancelButton;
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _keyboard.KeyDown -= CaptureNextKey; // safe even if recording was never started
        base.OnFormClosed(e);
    }

    private void OnRecordClick(object? sender, EventArgs e)
    {
        if (Selected == null)
            return;

        _statusLabel.Text = $"Press the new hotkey for \"{Selected.DisplayName}\"... (Esc to cancel)";
        _recordButton.Enabled = false;
        _keyboard.KeyDown += CaptureNextKey;
    }

    private void CaptureNextKey(KeyEventArgsLL e)
    {
        if (IsModifierOnly(e.VirtualKeyCode))
            return; // not a complete combo yet -- stay subscribed and wait for a real key

        _keyboard.KeyDown -= CaptureNextKey;
        e.Handled = true;
        _recordButton.Enabled = true;
        _statusLabel.Text = string.Empty;

        if (e.VirtualKeyCode == VK_ESCAPE)
            return;

        var action = Selected;
        if (action == null)
            return;

        action.Hotkey = new HotkeyCombo(e.Alt, e.Ctrl, e.Shift, e.Win, e.VirtualKeyCode);
        RefreshRow(action);
    }

    private void OnResetClick(object? sender, EventArgs e)
    {
        var action = Selected;
        if (action == null)
            return;

        action.Hotkey = action.DefaultHotkey;
        RefreshRow(action);
    }

    private void OnOkClick(object? sender, EventArgs e)
    {
        var conflicts = _actions
            .Where(a => a.Enabled && !a.Hotkey.IsEmpty)
            .GroupBy(a => a.Hotkey)
            .Where(g => g.Count() > 1)
            .ToList();

        if (conflicts.Count == 0)
            return;

        var summary = string.Join("\n", conflicts.Select(g =>
            $"{g.Key}: {string.Join(", ", g.Select(a => a.DisplayName))}"));

        var result = MessageBox.Show(
            $"These enabled actions share the same hotkey; only one will actually fire:\n\n{summary}\n\nSave anyway?",
            "Hotkey conflicts", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);

        if (result == DialogResult.No)
            DialogResult = DialogResult.None; // keep the dialog open
    }

    private void RevertToSnapshot()
    {
        foreach (var action in _actions)
        {
            if (_snapshot.TryGetValue(action.Id, out var s))
            {
                action.Enabled = s.Enabled;
                action.Hotkey = s.Hotkey;
            }
        }
    }

    private void RefreshRow(ActionDefinition action)
    {
        foreach (ListViewItem item in _list.Items)
        {
            if (ReferenceEquals(item.Tag, action))
            {
                item.SubItems[2].Text = action.Hotkey.ToString();
                break;
            }
        }
    }

    private static bool IsModifierOnly(int vk) => vk is VK_LMENU or VK_RMENU or VK_MENU
        or VK_LCONTROL or VK_RCONTROL or VK_CONTROL
        or VK_LSHIFT or VK_RSHIFT or VK_SHIFT
        or VK_LWIN or VK_RWIN;
}
