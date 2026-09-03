using System.Drawing;
using System.Windows.Forms;

namespace WindowControl.Config;

/// <summary>Minimal single-field text prompt, used to rename a Sequence. (Distinct from UI.RenameDialog, which is specifically for window titles.)</summary>
internal sealed class RenameDialogGeneric : Form
{
    private readonly TextBox _textBox;

    public string Value => _textBox.Text.Trim();

    public RenameDialogGeneric(string title, string currentValue)
    {
        Text = title;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterParent;
        MinimizeBox = false;
        MaximizeBox = false;
        ClientSize = new Size(320, 90);

        _textBox = new TextBox { Text = currentValue, Left = 12, Top = 12, Width = 296 };
        var ok = new Button { Text = "OK", DialogResult = DialogResult.OK, Left = 152, Top = 48, Width = 75 };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 233, Top = 48, Width = 75 };

        Controls.Add(_textBox);
        Controls.Add(ok);
        Controls.Add(cancel);

        AcceptButton = ok;
        CancelButton = cancel;

        Shown += (_, _) =>
        {
            _textBox.Focus();
            _textBox.SelectAll();
        };
    }
}
