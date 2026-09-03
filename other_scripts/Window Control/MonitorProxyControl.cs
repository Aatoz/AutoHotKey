using System.Drawing;
using System.Windows.Forms;

namespace WindowControl.Config;

/// <summary>
/// Miniature "demo window" editor: draws a proxy for a monitor's work area
/// with a draggable/resizable rectangle representing one sequence step. Drag
/// the rectangle's body to move it; drag the small grip at its bottom-right
/// corner to resize it. StepRect is always normalized (0..1) against the
/// proxy's own bounds, so it's resolution-independent.
/// </summary>
internal sealed class MonitorProxyControl : Control
{
    private const int GripSize = 10;
    private const float MinFraction = 0.05f;

    private RectangleF _stepRect = new(0.25f, 0.25f, 0.5f, 0.5f);
    private DragMode _dragMode;
    private Point _dragStartMouse;
    private RectangleF _dragStartRect;

    private enum DragMode { None, Move, Resize }

    /// <summary>Raised once, when a drag (move or resize) finishes -- not on every intermediate mouse-move.</summary>
    public event EventHandler? StepRectChanged;

    public RectangleF StepRect
    {
        get => _stepRect;
        set
        {
            _stepRect = Clamp(value);
            Invalidate();
        }
    }

    public MonitorProxyControl()
    {
        DoubleBuffered = true;
        BackColor = Color.FromArgb(30, 30, 30);
        BorderStyle = BorderStyle.FixedSingle;
        MinimumSize = new Size(160, 90);
    }

    private Rectangle ToPixels(RectangleF frac) => new(
        (int)(frac.X * ClientSize.Width),
        (int)(frac.Y * ClientSize.Height),
        (int)(frac.Width * ClientSize.Width),
        (int)(frac.Height * ClientSize.Height));

    private static RectangleF Clamp(RectangleF r)
    {
        float w = Math.Clamp(r.Width, MinFraction, 1f);
        float h = Math.Clamp(r.Height, MinFraction, 1f);
        float x = Math.Clamp(r.X, 0f, 1f - w);
        float y = Math.Clamp(r.Y, 0f, 1f - h);
        return new RectangleF(x, y, w, h);
    }

    private Rectangle GripBounds()
    {
        var px = ToPixels(_stepRect);
        return new Rectangle(px.Right - GripSize, px.Bottom - GripSize, GripSize, GripSize);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);

        var stepPx = ToPixels(_stepRect);
        using var fill = new SolidBrush(Color.FromArgb(120, 70, 130, 220));
        using var border = new Pen(Color.FromArgb(220, 120, 170, 255), 2);
        e.Graphics.FillRectangle(fill, stepPx);
        e.Graphics.DrawRectangle(border, stepPx);

        using var gripBrush = new SolidBrush(Color.White);
        e.Graphics.FillRectangle(gripBrush, GripBounds());
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);

        if (GripBounds().Contains(e.Location))
            _dragMode = DragMode.Resize;
        else if (ToPixels(_stepRect).Contains(e.Location))
            _dragMode = DragMode.Move;
        else
            _dragMode = DragMode.None;

        _dragStartMouse = e.Location;
        _dragStartRect = _stepRect;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);

        Cursor = GripBounds().Contains(e.Location) ? Cursors.SizeNWSE : Cursors.Default;

        if (_dragMode == DragMode.None || ClientSize.Width == 0 || ClientSize.Height == 0)
            return;

        float dx = (float)(e.X - _dragStartMouse.X) / ClientSize.Width;
        float dy = (float)(e.Y - _dragStartMouse.Y) / ClientSize.Height;

        StepRect = _dragMode == DragMode.Move
            ? new RectangleF(_dragStartRect.X + dx, _dragStartRect.Y + dy, _dragStartRect.Width, _dragStartRect.Height)
            : new RectangleF(_dragStartRect.X, _dragStartRect.Y, _dragStartRect.Width + dx, _dragStartRect.Height + dy);
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (_dragMode != DragMode.None)
            StepRectChanged?.Invoke(this, EventArgs.Empty);
        _dragMode = DragMode.None;
    }
}
