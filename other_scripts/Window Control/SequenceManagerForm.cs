using System.Drawing;
using System.Windows.Forms;
using WindowControl.Hooks;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.Config;

/// <summary>
/// Manages the full list of Sequences: add/rename/delete a sequence, rebind
/// its hotkey, and add/edit/reorder/remove its steps. Unlike SettingsForm,
/// edits here take effect immediately on the passed-in list (there's no
/// separate Cancel-discards-everything mode) -- simpler, and consistent
/// with how this kind of editor usually works elsewhere (PowerToys
/// FancyZones, etc).
/// </summary>
internal sealed class SequenceManagerForm : Form
{
    private readonly List<SequenceDefinition> _sequences;
    private readonly KeyboardHook _keyboard;

    private readonly ListBox _sequenceList;
    private readonly ListBox _stepList;
    private readonly CheckBox _enabledCheckBox;
    private readonly Label _hotkeyLabel;
    private readonly Button _hotkeyButton;
    private readonly Button _addStepButton;
    private readonly Button _editStepButton;
    private readonly Button _removeStepButton;
    private readonly Button _moveUpButton;
    private readonly Button _moveDownButton;
    private readonly Label _statusLabel;

    private SequenceDefinition? Selected =>
        _sequenceList.SelectedIndex >= 0 ? _sequences[_sequenceList.SelectedIndex] : null;

    public SequenceManagerForm(List<SequenceDefinition> sequences, KeyboardHook keyboard)
    {
        _sequences = sequences;
        _keyboard = keyboard;

        Text = "Manage Sequences";
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        ClientSize = new Size(620, 420);
        MinimumSize = new Size(560, 380);

        // --- Left: sequence list -----------------------------------------------

        _sequenceList = new ListBox { Location = new Point(12, 12), Size = new Size(200, 300) };
        _sequenceList.SelectedIndexChanged += (_, _) => RefreshDetailPanel();

        var addSeqButton = new Button { Text = "Add", Location = new Point(12, 318), Width = 60 };
        addSeqButton.Click += (_, _) => AddSequence();
        var renameSeqButton = new Button { Text = "Rename", Location = new Point(78, 318), Width = 66 };
        renameSeqButton.Click += (_, _) => RenameSequence();
        var deleteSeqButton = new Button { Text = "Delete", Location = new Point(150, 318), Width = 62 };
        deleteSeqButton.Click += (_, _) => DeleteSequence();

        // --- Right: selected sequence's details ---------------------------------

        _enabledCheckBox = new CheckBox { Text = "Enabled", Location = new Point(228, 12), AutoSize = true };
        _enabledCheckBox.CheckedChanged += (_, _) =>
        {
            if (Selected != null)
                Selected.Enabled = _enabledCheckBox.Checked;
        };

        _hotkeyLabel = new Label { Location = new Point(228, 40), AutoSize = true, Font = new Font(Font, FontStyle.Bold) };
        _hotkeyButton = new Button { Text = "Change Hotkey...", Location = new Point(228, 60), AutoSize = true };
        _hotkeyButton.Click += OnRecordHotkeyClick;

        var stepsLabel = new Label { Text = "Steps (applied in order, cycling on repeated presses):", Location = new Point(228, 96), AutoSize = true };
        _stepList = new ListBox { Location = new Point(228, 116), Size = new Size(380, 160) };

        _addStepButton = new Button { Text = "Add Step...", Location = new Point(228, 284), AutoSize = true };
        _addStepButton.Click += (_, _) => AddStep();
        _editStepButton = new Button { Text = "Edit Step...", Location = new Point(322, 284), AutoSize = true };
        _editStepButton.Click += (_, _) => EditStep();
        _removeStepButton = new Button { Text = "Remove Step", Location = new Point(416, 284), AutoSize = true };
        _removeStepButton.Click += (_, _) => RemoveStep();
        _moveUpButton = new Button { Text = "Move Up", Location = new Point(228, 314), AutoSize = true };
        _moveUpButton.Click += (_, _) => MoveStep(-1);
        _moveDownButton = new Button { Text = "Move Down", Location = new Point(322, 314), AutoSize = true };
        _moveDownButton.Click += (_, _) => MoveStep(1);

        _statusLabel = new Label { Location = new Point(12, 350), AutoSize = true, ForeColor = SystemColors.GrayText };

        var closeButton = new Button { Text = "Close", DialogResult = DialogResult.OK, Location = new Point(520, 380), AutoSize = true };

        Controls.Add(_sequenceList);
        Controls.Add(addSeqButton);
        Controls.Add(renameSeqButton);
        Controls.Add(deleteSeqButton);
        Controls.Add(_enabledCheckBox);
        Controls.Add(_hotkeyLabel);
        Controls.Add(_hotkeyButton);
        Controls.Add(stepsLabel);
        Controls.Add(_stepList);
        Controls.Add(_addStepButton);
        Controls.Add(_editStepButton);
        Controls.Add(_removeStepButton);
        Controls.Add(_moveUpButton);
        Controls.Add(_moveDownButton);
        Controls.Add(_statusLabel);
        Controls.Add(closeButton);

        AcceptButton = closeButton;
        CancelButton = closeButton;

        RepopulateSequenceList();
        if (_sequenceList.Items.Count > 0)
            _sequenceList.SelectedIndex = 0;
        RefreshDetailPanel();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _keyboard.KeyDown -= CaptureNextKey; // safe even if recording was never started
        base.OnFormClosed(e);
    }

    // --- Sequence list actions -------------------------------------------------

    private void AddSequence()
    {
        var seq = new SequenceDefinition
        {
            Id = $"seq-{Guid.NewGuid():N}",
            DisplayName = "New Sequence",
            Hotkey = HotkeyCombo.None,
            Steps = { new SequenceStep(0.25, 0.25, 0.5, 0.5) },
        };
        _sequences.Add(seq);
        RepopulateSequenceList();
        _sequenceList.SelectedIndex = _sequences.IndexOf(seq);
    }

    private void RenameSequence()
    {
        var seq = Selected;
        if (seq == null)
            return;

        using var dlg = new RenameDialogGeneric("Rename Sequence", seq.DisplayName);
        if (dlg.ShowDialog() == DialogResult.OK && dlg.Value.Length > 0)
        {
            seq.DisplayName = dlg.Value;
            RepopulateSequenceList();
        }
    }

    private void DeleteSequence()
    {
        var seq = Selected;
        if (seq == null)
            return;

        _sequences.Remove(seq);
        RepopulateSequenceList();
        RefreshDetailPanel();
    }

    private void RepopulateSequenceList()
    {
        int selectedIndex = _sequenceList.SelectedIndex;
        _sequenceList.Items.Clear();
        foreach (var seq in _sequences)
            _sequenceList.Items.Add(seq.DisplayName);
        if (selectedIndex >= 0 && selectedIndex < _sequenceList.Items.Count)
            _sequenceList.SelectedIndex = selectedIndex;
    }

    // --- Step list actions -------------------------------------------------------

    private void AddStep()
    {
        var seq = Selected;
        if (seq == null)
            return;

        using var dlg = new StepEditorDialog(null);
        if (dlg.ShowDialog() == DialogResult.OK)
        {
            seq.Steps.Add(dlg.Result);
            RefreshStepList();
        }
    }

    private void EditStep()
    {
        var seq = Selected;
        int index = _stepList.SelectedIndex;
        if (seq == null || index < 0)
            return;

        using var dlg = new StepEditorDialog(seq.Steps[index]);
        if (dlg.ShowDialog() == DialogResult.OK)
        {
            seq.Steps[index] = dlg.Result;
            RefreshStepList();
            _stepList.SelectedIndex = index;
        }
    }

    private void RemoveStep()
    {
        var seq = Selected;
        int index = _stepList.SelectedIndex;
        if (seq == null || index < 0)
            return;

        seq.Steps.RemoveAt(index);
        RefreshStepList();
    }

    private void MoveStep(int direction)
    {
        var seq = Selected;
        int index = _stepList.SelectedIndex;
        int target = index + direction;
        if (seq == null || index < 0 || target < 0 || target >= seq.Steps.Count)
            return;

        (seq.Steps[index], seq.Steps[target]) = (seq.Steps[target], seq.Steps[index]);
        RefreshStepList();
        _stepList.SelectedIndex = target;
    }

    // --- Hotkey recording (same approach as SettingsForm) -------------------------

    private void OnRecordHotkeyClick(object? sender, EventArgs e)
    {
        if (Selected == null)
            return;

        _statusLabel.Text = "Press the new hotkey... (Esc to cancel)";
        _hotkeyButton.Enabled = false;
        _keyboard.KeyDown += CaptureNextKey;
    }

    private void CaptureNextKey(KeyEventArgsLL e)
    {
        if (IsModifierOnly(e.VirtualKeyCode))
            return; // not a complete combo yet -- stay subscribed and wait for a real key

        _keyboard.KeyDown -= CaptureNextKey;
        e.Handled = true;
        _hotkeyButton.Enabled = true;
        _statusLabel.Text = string.Empty;

        if (e.VirtualKeyCode == VK_ESCAPE)
            return;

        var seq = Selected;
        if (seq == null)
            return;

        seq.Hotkey = new HotkeyCombo(e.Alt, e.Ctrl, e.Shift, e.Win, e.VirtualKeyCode);
        RefreshDetailPanel();
    }

    private static bool IsModifierOnly(int vk) => vk is VK_LMENU or VK_RMENU or VK_MENU
        or VK_LCONTROL or VK_RCONTROL or VK_CONTROL
        or VK_LSHIFT or VK_RSHIFT or VK_SHIFT
        or VK_LWIN or VK_RWIN;

    // --- Shared refresh -----------------------------------------------------------

    private void RefreshDetailPanel()
    {
        var seq = Selected;
        bool has = seq != null;

        _enabledCheckBox.Enabled = has;
        _hotkeyButton.Enabled = has;
        _addStepButton.Enabled = has;

        if (seq == null)
        {
            _enabledCheckBox.Checked = false;
            _hotkeyLabel.Text = string.Empty;
            _stepList.Items.Clear();
            return;
        }

        _enabledCheckBox.Checked = seq.Enabled;
        _hotkeyLabel.Text = seq.Hotkey.ToString();
        RefreshStepList();
    }

    private void RefreshStepList()
    {
        var seq = Selected;
        _stepList.Items.Clear();
        if (seq == null)
            return;

        for (int i = 0; i < seq.Steps.Count; i++)
        {
            var s = seq.Steps[i];
            _stepList.Items.Add($"{i + 1}. Left {s.X:P0}, Top {s.Y:P0}, Width {s.Width:P0}, Height {s.Height:P0}");
        }

        bool hasSelection = _stepList.Items.Count > 0;
        _editStepButton.Enabled = hasSelection;
        _removeStepButton.Enabled = hasSelection;
        _moveUpButton.Enabled = hasSelection;
        _moveDownButton.Enabled = hasSelection;
    }
}
