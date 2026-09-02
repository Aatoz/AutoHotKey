using System.Text;
using System.Windows.Forms;
using static WindowControl.Native.NativeMethods;

namespace WindowControl.WindowOps;

internal enum Edge { Left, Right, Top, Bottom }
internal enum Corner { TopLeft, TopRight, BottomLeft, BottomRight }
internal enum MonitorDirection { Left, Right }

/// <summary>
/// All the actual window-manipulation operations (move, resize, enable/disable,
/// border toggle, rename, control inspection). Knows nothing about hooks,
/// hotkeys, or the tray UI -- it just operates on window handles, so it can be
/// exercised independently of the global hooks that drive it.
/// </summary>
internal sealed class WindowController
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

    public static nint WindowUnderPoint(int x, int y)
    {
        nint hWnd = WindowFromPoint(new POINT { X = x, Y = y });
        return hWnd == 0 ? 0 : GetAncestor(hWnd, GA_ROOT);
    }

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

    // --- Close ---------------------------------------------------------------

    /// <summary>Asks a window to close, the same way clicking its X button or Alt+F4 does.</summary>
    public static void Close(nint hWnd) => PostMessage(hWnd, WM_CLOSE, 0, 0);

    /// <summary>Closes every top-level, visible, approved window.</summary>
    public void CloseAllWindows() => CloseAllExcept(0);

    /// <summary>Closes every top-level, visible, approved window except the given one.</summary>
    public void CloseAllExcept(nint keepHWnd)
    {
        EnumWindows((hWnd, _) =>
        {
            if (hWnd != keepHWnd && IsWindowVisible(hWnd) && IsApprovedWindow(hWnd) && GetTitle(hWnd).Length > 0)
                Close(hWnd);
            return true;
        }, 0);
    }

    // --- Maximize / minimize ---------------------------------------------------

    public static void Maximize(nint hWnd) => ShowWindow(hWnd, SW_MAXIMIZE);

    public static void Minimize(nint hWnd) => ShowWindow(hWnd, SW_MINIMIZE);

    public void MaximizeHorizontally(nint hWnd)
    {
        RestoreIfMaximized(hWnd);
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        var rect = GetRect(hWnd);
        SetWindowPos(hWnd, 0, work.Left, rect.Top, work.Width, rect.Height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    public void MaximizeVertically(nint hWnd)
    {
        RestoreIfMaximized(hWnd);
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        var rect = GetRect(hWnd);
        SetWindowPos(hWnd, 0, rect.Left, work.Top, rect.Width, work.Height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    /// <summary>Stretches the window across the combined bounds of every monitor.</summary>
    public void MaximizeAcrossAllMonitors(nint hWnd)
    {
        RestoreIfMaximized(hWnd);
        var v = SystemInformation.VirtualScreen;
        SetWindowPos(hWnd, 0, v.Left, v.Top, v.Width, v.Height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    private static void RestoreIfMaximized(nint hWnd) => ShowWindow(hWnd, SW_RESTORE);

    // --- Half / quarter resize -------------------------------------------------

    public void ResizeToHalf(nint hWnd, Edge edge)
    {
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        var (x, y, w, h) = edge switch
        {
            Edge.Left => (work.Left, work.Top, work.Width / 2, work.Height),
            Edge.Right => (work.Left + work.Width / 2, work.Top, work.Width / 2, work.Height),
            Edge.Top => (work.Left, work.Top, work.Width, work.Height / 2),
            Edge.Bottom => (work.Left, work.Top + work.Height / 2, work.Width, work.Height / 2),
            _ => (work.Left, work.Top, work.Width, work.Height),
        };
        SetWindowPos(hWnd, 0, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    public void ResizeToCenterFraction(nint hWnd, double fraction)
    {
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        int w = (int)(work.Width * fraction);
        int h = (int)(work.Height * fraction);
        int x = work.Left + (work.Width - w) / 2;
        int y = work.Top + (work.Height - h) / 2;
        SetWindowPos(hWnd, 0, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    /// <summary>Quarter-size snap into a literal corner of the current monitor's work area.</summary>
    public void SnapToCorner(nint hWnd, Corner corner)
    {
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        int w = work.Width / 2;
        int h = work.Height / 2;
        var (x, y) = corner switch
        {
            Corner.TopLeft => (work.Left, work.Top),
            Corner.TopRight => (work.Left + work.Width - w, work.Top),
            Corner.BottomLeft => (work.Left, work.Top + work.Height - h),
            Corner.BottomRight => (work.Left + work.Width - w, work.Top + work.Height - h),
            _ => (work.Left, work.Top),
        };
        SetWindowPos(hWnd, 0, x, y, w, h, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    /// <summary>
    /// Aligns just one edge of the window with the matching edge of its
    /// monitor's work area -- e.g. Edge.Left sets X so the window's left
    /// edge touches the work area's left edge. The other axis, and both
    /// dimensions, are left exactly as they are.
    /// </summary>
    public void SnapToEdge(nint hWnd, Edge edge)
    {
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        var rect = GetRect(hWnd);

        switch (edge)
        {
            case Edge.Left:
                Move(hWnd, work.Left, rect.Top);
                break;
            case Edge.Right:
                Move(hWnd, work.Right - rect.Width, rect.Top);
                break;
            case Edge.Top:
                Move(hWnd, rect.Left, work.Top);
                break;
            case Edge.Bottom:
                Move(hWnd, rect.Left, work.Bottom - rect.Height);
                break;
        }
    }

    /// <summary>Repositions the window to the center of the monitor's work area, keeping its current size.</summary>
    public void SnapToCenter(nint hWnd)
    {
        var work = Screen.FromHandle((IntPtr)hWnd).WorkingArea;
        var rect = GetRect(hWnd);
        int x = work.Left + (work.Width - rect.Width) / 2;
        int y = work.Top + (work.Height - rect.Height) / 2;
        Move(hWnd, x, y);
    }

    /// <summary>Centers the window on its owner window, or on the monitor if it has no owner.</summary>
    public void SnapToCenterOfParent(nint hWnd)
    {
        nint owner = GetWindow(hWnd, GW_OWNER);
        var rect = GetRect(hWnd);

        if (owner != 0)
        {
            var ownerRect = GetRect(owner);
            int x = ownerRect.Left + (ownerRect.Width - rect.Width) / 2;
            int y = ownerRect.Top + (ownerRect.Height - rect.Height) / 2;
            Move(hWnd, x, y);
        }
        else
        {
            SnapToCenter(hWnd);
        }
    }

    // --- Move to adjacent monitor ------------------------------------------------

    public void MoveToMonitor(nint hWnd, MonitorDirection direction)
    {
        var screens = Screen.AllScreens.OrderBy(s => s.Bounds.Left).ToArray();
        if (screens.Length < 2)
            return;

        var current = Screen.FromHandle((IntPtr)hWnd);
        int index = Array.IndexOf(screens, current);
        if (index < 0)
            return;

        int targetIndex = direction == MonitorDirection.Right
            ? (index + 1) % screens.Length
            : (index - 1 + screens.Length) % screens.Length;

        var fromWork = current.WorkingArea;
        var toWork = screens[targetIndex].WorkingArea;
        var rect = GetRect(hWnd);

        // Preserve the window's offset from its current monitor's work-area
        // corner, translated onto the target monitor, clamped so it can't end
        // up hanging off the edge of a smaller target monitor.
        int offsetX = rect.Left - fromWork.Left;
        int offsetY = rect.Top - fromWork.Top;
        int newX = Math.Clamp(toWork.Left + offsetX, toWork.Left, Math.Max(toWork.Left, toWork.Right - rect.Width));
        int newY = Math.Clamp(toWork.Top + offsetY, toWork.Top, Math.Max(toWork.Top, toWork.Bottom - rect.Height));

        Move(hWnd, newX, newY);
    }

    // --- Always on top -----------------------------------------------------------

    /// <summary>Toggles topmost (always-on-top) on the window. Returns the new topmost state.</summary>
    public static bool ToggleAlwaysOnTop(nint hWnd)
    {
        long exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
        bool nowTopmost = (exStyle & WS_EX_TOPMOST) == 0;
        SetWindowPos(hWnd, nowTopmost ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        return nowTopmost;
    }

    // --- Transparency --------------------------------------------------------------

    private const byte MinAlpha = 40;
    private const byte TransparencyStep = 25;

    public static void AdjustTransparency(nint hWnd, int delta)
    {
        int exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
        SetWindowLong(hWnd, GWL_EXSTYLE, (int)(exStyle | WS_EX_LAYERED));

        byte current = GetLayeredWindowAttributes(hWnd, out _, out byte alpha, out _) ? alpha : (byte)255;
        int next = Math.Clamp(current + delta, MinAlpha, 255);
        SetLayeredWindowAttributes(hWnd, 0, (byte)next, LWA_ALPHA);
    }

    public static void IncrementTransparency(nint hWnd) => AdjustTransparency(hWnd, TransparencyStep);

    public static void DecrementTransparency(nint hWnd) => AdjustTransparency(hWnd, -TransparencyStep);

    public static void DisableTransparency(nint hWnd)
    {
        SetLayeredWindowAttributes(hWnd, 0, 255, LWA_ALPHA);
        int exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
        SetWindowLong(hWnd, GWL_EXSTYLE, (int)(exStyle & ~WS_EX_LAYERED));
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
