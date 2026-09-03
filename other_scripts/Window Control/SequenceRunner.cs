using WindowControl.WindowOps;

namespace WindowControl.Config;

/// <summary>
/// Applies a sequence's next step to a window, tracking per-(sequence,
/// window) position statefully -- deliberately NOT re-detecting "which step
/// the window is currently on" from its geometry. That's what the original
/// WinSplit Revolution did, and its own documented weak point: if the
/// window's current size doesn't exactly match a preset (a manual resize, a
/// different action touched it, DPI rounding), it silently resets to the
/// first step instead of continuing. Remembering the last-applied index
/// per window avoids that class of bug entirely.
/// </summary>
internal sealed class SequenceRunner
{
    // Same caveat as WindowController's border-style cache: HWNDs can be
    // reused after a window closes, so a stale entry could in principle
    // apply to an unrelated later window that happens to get the same
    // handle. Existing precedent in this codebase accepts that same
    // theoretical edge case rather than adding window-identity tracking.
    private readonly Dictionary<(string SequenceId, nint Hwnd), int> _lastIndex = new();
    private readonly WindowController _controller;

    public SequenceRunner(WindowController controller)
    {
        _controller = controller;
    }

    public void Apply(SequenceDefinition sequence, nint hWnd)
    {
        if (sequence.Steps.Count == 0)
            return;

        var key = (sequence.Id, hWnd);
        int next = _lastIndex.TryGetValue(key, out int last) ? (last + 1) % sequence.Steps.Count : 0;
        var step = sequence.Steps[next];

        _controller.SetFractionalRect(hWnd, step.X, step.Y, step.Width, step.Height);
        _lastIndex[key] = next;
    }
}
