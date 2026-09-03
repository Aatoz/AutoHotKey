using System.Drawing;
using System.Windows.Forms;

namespace WindowControl.Config;

/// <summary>Modal for creating/editing one sequence step -- drag the proxy rectangle, or type exact percentages.</summary>
internal sealed class StepEditorDialog : Form
{
    private readonly MonitorProxyControl _proxy;
    private readonly NumericUpDown _xBox;
    private readonly NumericUpDown _yBox;
    private readonly NumericUpDown _wBox;
    private readonly NumericUpDown _hBox;
    private bool _syncing;

    public SequenceStep Result { get; private set; }

    public StepEditorDialog(SequenceStep? initial)
    {
        Text = "Position Step";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(420, 340);

        var start = initial ?? new SequenceStep(0.25, 0.25, 0.5, 0.5);
        Result = start;

        _proxy = new MonitorProxyControl
        {
            Location = new Point(12, 12),
            Size = new Size(396, 220),
            StepRect = new RectangleF((float)start.X, (float)start.Y, (float)start.Width, (float)start.Height),
        };
        _proxy.StepRectChanged += (_, _) => SyncFromProxy();

        (_xBox, var xLabel) = MakePercentField("Left", 12, 244);
        (_yBox, var yLabel) = MakePercentField("Top", 118, 244);
        (_wBox, var wLabel) = MakePercentField("Width", 224, 244);
        (_hBox, var hLabel) = MakePercentField("Height", 330, 244);
        SyncFromProxy();
        _xBox.ValueChanged += (_, _) => SyncFromFields();
        _yBox.ValueChanged += (_, _) => SyncFromFields();
        _wBox.ValueChanged += (_, _) => SyncFromFields();
        _hBox.ValueChanged += (_, _) => SyncFromFields();

        var hint = new Label
        {
            Text = "Drag the box to move it, its corner grip to resize it -- or type exact percentages below.",
            Location = new Point(12, 280),
            AutoSize = true,
            ForeColor = SystemColors.GrayText,
        };

        var ok = new Button { Text = "Save Step", DialogResult = DialogResult.OK, Location = new Point(224, 300), AutoSize = true };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Location = new Point(330, 300), AutoSize = true };
        ok.Click += (_, _) => Result = new SequenceStep(
            (double)_xBox.Value / 100, (double)_yBox.Value / 100, (double)_wBox.Value / 100, (double)_hBox.Value / 100);

        Controls.Add(_proxy);
        Controls.Add(xLabel);
        Controls.Add(_xBox);
        Controls.Add(yLabel);
        Controls.Add(_yBox);
        Controls.Add(wLabel);
        Controls.Add(_wBox);
        Controls.Add(hLabel);
        Controls.Add(_hBox);
        Controls.Add(hint);
        Controls.Add(ok);
        Controls.Add(cancel);

        AcceptButton = ok;
        CancelButton = cancel;
    }

    private static (NumericUpDown Box, Label Label) MakePercentField(string label, int x, int y)
    {
        var lbl = new Label { Text = label + " %", Location = new Point(x, y), AutoSize = true };
        var box = new NumericUpDown { Location = new Point(x, y + 16), Width = 80, Minimum = 0, Maximum = 100, DecimalPlaces = 0 };
        return (box, lbl);
    }

    private void SyncFromProxy()
    {
        if (_syncing)
            return;

        _syncing = true;
        _xBox.Value = (decimal)Math.Round(_proxy.StepRect.X * 100);
        _yBox.Value = (decimal)Math.Round(_proxy.StepRect.Y * 100);
        _wBox.Value = (decimal)Math.Round(_proxy.StepRect.Width * 100);
        _hBox.Value = (decimal)Math.Round(_proxy.StepRect.Height * 100);
        _syncing = false;
    }

    private void SyncFromFields()
    {
        if (_syncing)
            return;

        _syncing = true;
        _proxy.StepRect = new RectangleF(
            (float)_xBox.Value / 100f, (float)_yBox.Value / 100f,
            (float)_wBox.Value / 100f, (float)_hBox.Value / 100f);
        _syncing = false;
    }
}
