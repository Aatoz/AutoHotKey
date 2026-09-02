using System.Drawing;
using System.Windows.Forms;

namespace WindowControl.UI;

/// <summary>Small borderless popup used in place of AHK's Tooltip()/SetTimer combo for brief status messages.</summary>
internal sealed class TransientTooltip : Form
{
    private readonly Timer _timer = new() { Interval = 1500 };

    private TransientTooltip(string text, Point screenLocation)
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.LightYellow;
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Padding = new Padding(4);

        var label = new Label
        {
            Text = text,
            AutoSize = true,
            Font = new Font(FontFamily.GenericSansSerif, 9f),
        };
        Controls.Add(label);

        Location = new Point(screenLocation.X + 12, screenLocation.Y + 12);
        _timer.Tick += (_, _) => Close();
    }

    /// <summary>Shows a status message near the given screen point for ~1.5s, then closes itself.</summary>
    public static void Show(string text, int screenX, int screenY)
    {
        var tip = new TransientTooltip(text, new Point(screenX, screenY));
        tip.FormClosed += (_, _) => tip._timer.Dispose();
        tip.Show();
        tip._timer.Start();
    }
}
