using System.Text;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.WindowOps;

/// <summary>
/// All the actual window-manipulation operations (move, resize, enable/disable,
/// border toggle, rename, control inspection). Knows nothing about hooks,
/// hotkeys, or the tray UI -- it just operates on window handles, so it can be
/// exercised independently of the global hooks that drive it.
/// </summary>
public sealed class WindowController
{
    private const int MinWidth = 50;
    private const int MinHeight = 50;

    // Mirrors IsApprovedHwnd() from the original script: windows that
    // shouldn't be moved/resized/disabled (desktop, taskbar, etc).
    private static readonly HashSet<string> DisallowedClasses = new(StringComparer.OrdinalIgnoreCase)
    {
        "WorkerW",
        "Shell_TrayWnd",
        "Progman",
        "SideBar_HTMLHostWindow",
    };

    // Styles we stripped for the border toggle, so we can restore the exact
    // original style rather than guessing at "the standard" border styles.
    private readonly Dictionary<nint, int> _savedStyles = new();

    public static nint WindowUnderPoint(int x, int y) => WindowFromPoint(new POINT { X = x, Y = y });

    public bool IsApprovedWindow(nint hWnd)
    {
        if (hWnd == 0)
            return false;

        return !DisallowedClasses.Contains(GetClassNameOf(hWnd));
    }

    public static string GetClassNameOf(nint hWnd)
    {
        var sb = new StringBuilder(256);
        GetClassName(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static RECT GetRect(nint hWnd)
    {
        GetWindowRect(hWnd, out var rect);
        return rect;
    }

    public void Move(nint hWnd, int newX, int newY)
    {
        SetWindowPos(hWnd, 0, newX, newY, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    }

    public void Resize(nint hWnd, int newWidth, int newHeight)
    {
        newWidth = Math.Max(newWidth, MinWidth);
        newHeight = Math.Max(newHeight, MinHeight);
        SetWindowPos(hWnd, 0, 0, 0, newWidth, newHeight, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    }

    /// <summary>Toggles Enabled/Disabled on the given window. Returns the new enabled state.</summary>
    public bool ToggleEnabled(nint hWnd)
    {
        bool nowEnabled = !IsWindowEnabled(hWnd);
        EnableWindow(hWnd, nowEnabled);
        return nowEnabled;
    }

    /// <summary>Toggles the caption/border on the given window. Returns the new "has border" state.</summary>
    public bool ToggleBorder(nint hWnd)
    {
        const long borderBits = WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

        int style = GetWindowLong(hWnd, GWL_STYLE);
        bool hasBorder = (style & borderBits) != 0;

        if (hasBorder)
        {
            _savedStyles[hWnd] = style;
            SetWindowLong(hWnd, GWL_STYLE, (int)(style & ~borderBits));
        }
        else if (_savedStyles.TryGetValue(hWnd, out int savedStyle))
        {
            SetWindowLong(hWnd, GWL_STYLE, savedStyle);
            _savedStyles.Remove(hWnd);
        }
        else
        {
            // We never stripped this window's border ourselves -- add the
            // standard bits back rather than doing nothing.
            SetWindowLong(hWnd, GWL_STYLE, (int)(style | borderBits));
        }

        SetWindowPos(hWnd, 0, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

        return !hasBorder;
    }

    public static string GetTitle(nint hWnd)
    {
        var sb = new StringBuilder(512);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static void SetTitle(nint hWnd, string title) => SetWindowText(hWnd, title);

    /// <summary>
    /// Describes the control under the given screen point, for the
    /// Alt+Shift+C "copy control info" hotkey. Note: the original AHK script
    /// labeled a control's Width/Height as "Right"/"Bottom" in the clipboard
    /// text, which was a mislabeling bug (ControlGetPos returns width/height,
    /// not right/bottom screen coordinates) -- this version labels them
    /// correctly.
    /// </summary>
    public static string? DescribeControlUnderCursor(int screenX, int screenY)
    {
        var screenPt = new POINT { X = screenX, Y = screenY };
        nint topLevel = WindowFromPoint(screenPt);
        if (topLevel == 0)
            return null;

        var clientPt = screenPt;
        ScreenToClient(topLevel, ref clientPt);
        nint control = RealChildWindowFromPoint(topLevel, clientPt);
        if (control == 0)
            control = topLevel;

        string text = GetTitle(control);
        GetWindowRect(control, out var rect);

        return $"Control:\t{text}\nLeft:\t{rect.Left}\nTop:\t{rect.Top}\nWidth:\t{rect.Width}\nHeight:\t{rect.Height}";
    }
}
