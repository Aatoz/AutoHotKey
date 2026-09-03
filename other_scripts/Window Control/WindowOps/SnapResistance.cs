namespace WindowControl.WindowOps;

/// <summary>Per-axis snap state, carried across mouse-move events for the duration of one drag.</summary>
internal struct AxisSnapState
{
    public bool Snapped;
    public int SnappedValue;
}

/// <summary>
/// Magnetic-edge snapping for the Alt+drag window move: when the dragged
/// window's visible edge passes near a monitor's work-area edge, it locks
/// there; small further movement is absorbed (resistance) until the cursor
/// has pulled far enough past the snap point to break free again.
///
/// Deliberately scoped to monitor edges only for now, not other windows'
/// edges -- window-to-window magnetism is a fair bit more work (live
/// enumeration/filtering of other top-level windows on every mouse-move)
/// and wasn't asked for. Worth adding later if it'd help.
/// </summary>
internal static class SnapResistance
{
    /// <summary>Distance (px) from a snap line at which the window locks to it.</summary>
    public const int SnapThreshold = 16;

    /// <summary>Additional cursor travel (px) past the snap point needed to break free once snapped.</summary>
    public const int ReleaseThreshold = 40;

    /// <summary>
    /// Computes the coordinate to actually use for one axis (X or Y) given
    /// the naive (unsnapped, delta-tracked) candidate, and returns the
    /// updated snap state for the next call.
    /// </summary>
    /// <param name="naiveValue">Where this axis would land with no snapping (window-rect coordinate, e.g. GetWindowRect's Left).</param>
    /// <param name="leadingInset">Border inset on the low side of this axis (Left for X, Top for Y) -- see WindowController.GetBorderInsets.</param>
    /// <param name="trailingInset">Border inset on the high side of this axis (Right for X, Bottom for Y).</param>
    /// <param name="size">The window's width (for X) or height (for Y) -- constant during a move, so this can be computed once at drag start.</param>
    /// <param name="lowLine">The monitor work area's low edge for this axis (Left for X, Top for Y).</param>
    /// <param name="highLine">The monitor work area's high edge for this axis (Right for X, Bottom for Y).</param>
    public static (int Value, AxisSnapState State) Apply(
        int naiveValue, int leadingInset, int trailingInset, int size,
        int lowLine, int highLine, AxisSnapState state)
    {
        if (state.Snapped)
        {
            if (Math.Abs(naiveValue - state.SnappedValue) <= ReleaseThreshold)
                return (state.SnappedValue, state);

            state.Snapped = false;
        }

        // The window's true visible edges if we used naiveValue as-is.
        int visualLow = naiveValue + leadingInset;
        int visualHigh = naiveValue + size - trailingInset;

        if (Math.Abs(visualLow - lowLine) <= SnapThreshold)
        {
            int snapped = lowLine - leadingInset;
            return (snapped, new AxisSnapState { Snapped = true, SnappedValue = snapped });
        }

        if (Math.Abs(visualHigh - highLine) <= SnapThreshold)
        {
            int snapped = highLine + trailingInset - size;
            return (snapped, new AxisSnapState { Snapped = true, SnappedValue = snapped });
        }

        return (naiveValue, default);
    }
}
