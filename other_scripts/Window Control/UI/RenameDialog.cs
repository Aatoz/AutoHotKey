using System.Drawing;
using System.Windows.Forms;

namespace WindowControl.UI;

/// <summary>Minimal replacement for AHK's InputBox, used to rename a window's title.</summary>
internal sealed class RenameDialog : Form
{
    private readonly TextBox _textBox;

    public string NewTitle => _textBox.Text;

    public RenameDialog(string currentTitle)
    {
        Text = "Set Window Title";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        StartPosition = FormStartPosition.CenterScreen;
        MinimizeBox = false;
        MaximizeBox = false;
        ShowInTaskbar = false;
        TopMost = true;
        ClientSize = new Size(420, 90);

        _textBox = new TextBox { Text = currentTitle, Left = 12, Top = 12, Width = 396 };
        var ok = new Button { Text = "OK", DialogResult = DialogResult.OK, Left = 252, Top = 48, Width = 75 };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, Left = 333, Top = 48, Width = 75 };

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
