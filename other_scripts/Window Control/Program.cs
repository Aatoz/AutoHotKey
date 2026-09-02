using System.Windows.Forms;
using WindowControl.UI;

namespace WindowControl;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            Application.Run(new TrayApplicationContext());
        }
        catch (InvalidOperationException ex)
        {
            MessageBox.Show(ex.Message, "Window Control", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
