using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Windows.Forms;
using Microsoft.Win32;

namespace AZZikr
{
    /// A bubble drawn once into a bitmap. `Anchor` is the point (in the bitmap) that sits above the pointer.
    sealed class BubbleImage : IDisposable
    {
        public Bitmap Bitmap;
        public Point Anchor;
        public int Pad;
        public void Dispose() => Bitmap?.Dispose();
    }

    /// Draws the six styles with GDI+, matching web/bubble.css and the Mac BubbleView.
    static class BubbleRenderer
    {
        static PrivateFontCollection amiri;
        static FontFamily AmiriFamily
        {
            get
            {
                if (amiri == null)
                {
                    amiri = new PrivateFontCollection();
                    var f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "web", "fonts", "AmiriQuran.ttf");
                    if (File.Exists(f)) amiri.AddFontFile(f);
                }
                return amiri.Families.Length > 0 ? amiri.Families[0] : new FontFamily("Times New Roman");
            }
        }
        static FontFamily UiFamily
        {
            get
            {
                try { return new FontFamily("Segoe UI Semibold"); } catch { return new FontFamily("Segoe UI"); }
            }
        }

        static Color C(int rgb, int a = 255) => Color.FromArgb(a, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);

        public static BubbleImage Render(string text, string style, float cssSize, bool dark, bool tail, float s)
        {
            bool bare = style == "text" || style == "callig";
            bool callig = style == "callig";
            var family = callig ? AmiriFamily : UiFamily;
            float em = cssSize * s * (callig ? 1.35f : 1f);

            var sf = new StringFormat(StringFormat.GenericTypographic)
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center,
                FormatFlags = StringFormatFlags.DirectionRightToLeft | StringFormatFlags.NoWrap
            };

            SizeF textSize;
            using (var probe = new Bitmap(1, 1))
            using (var pg = Graphics.FromImage(probe))
            using (var font = new Font(family, em, FontStyle.Regular, GraphicsUnit.Pixel))
            {
                pg.TextRenderingHint = TextRenderingHint.AntiAlias;
                textSize = pg.MeasureString(text, font, PointF.Empty, sf);
            }

            float padX = (bare ? 4 : 11) * s, padTop = (bare ? 2 : 5) * s, padBottom = (callig ? 7 : bare ? 2 : 6) * s;
            float lineH = em * (callig ? 1.6f : 1.5f);
            float w = (float)Math.Ceiling(textSize.Width + 2 * padX + 2 * s);
            float h = (float)Math.Ceiling(lineH + padTop + padBottom);
            float tailH = (tail && !bare) ? 5 * s : 0;
            int pad = (int)Math.Ceiling(12 * s);
            int bw = (int)(w + 2 * pad), bh = (int)(h + tailH + 2 * pad);

            var bmp = new Bitmap(bw, bh, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.CompositingQuality = CompositingQuality.HighQuality;
                g.Clear(Color.Transparent);

                var box = new RectangleF(pad, pad, w, h);
                var textRect = new RectangleF(box.X + padX, box.Y + padTop, w - 2 * padX, lineH);

                if (!bare)
                {
                    float radius = style == "tag" ? 8 * s : h / 2;
                    // soft shadow: a few expanding translucent layers, offset down
                    for (int i = 4; i >= 1; i--)
                    {
                        var sh = box; sh.Inflate(i * s, i * s); sh.Offset(0, 3 * s);
                        using (var p = Rounded(sh, radius + i * s))
                        using (var b = new SolidBrush(C(0x061230, style == "glass" || style == "tag" ? 7 : 10)))
                            g.FillPath(b, p);
                    }
                    Brush fill;
                    Color tailColor;
                    switch (style)
                    {
                        case "grad":
                            fill = new LinearGradientBrush(box, C(0x061230, 235), C(0x14349A, 230), LinearGradientMode.ForwardDiagonal);
                            tailColor = C(0x0C205F, 235); break;
                        case "glass":
                            fill = new SolidBrush(C(0xFFFFFF, 220)); tailColor = C(0xFFFFFF, 220); break;
                        case "tag":
                            fill = new SolidBrush(Color.White); tailColor = Color.White; break;
                        default: // calm
                            fill = new SolidBrush(C(0x08163C, 225)); tailColor = C(0x08163C, 225); break;
                    }
                    using (fill)
                    using (var p = Rounded(box, radius))
                    {
                        g.FillPath(fill, p);
                        if (style == "tag")
                        {
                            var clip = g.Clip; g.SetClip(p);
                            using (var blue = new SolidBrush(C(0x004ACC))) g.FillRectangle(blue, box.Right - 3 * s, box.Y, 3 * s, box.Height);
                            g.Clip = clip;
                        }
                        else
                        {
                            using (var pen = new Pen(style == "glass" ? Color.White : C(0xFFFFFF, 22), 1 * s)) g.DrawPath(pen, p);
                        }
                    }
                    if (tailH > 0)
                    {
                        float cx = box.X + w / 2, by = box.Bottom - 1;
                        using (var tb = new SolidBrush(tailColor))
                            g.FillPolygon(tb, new[] { new PointF(cx - 5 * s, by), new PointF(cx + 5 * s, by), new PointF(cx, by + tailH) });
                    }
                }

                using (var path = new GraphicsPath())
                {
                    path.AddString(text, family, (int)FontStyle.Regular, em, textRect, sf);
                    Color fg;
                    if (bare)
                    {
                        // halo so it reads on any background (white on light mode, dark on dark mode)
                        var halo = dark ? Color.Black : Color.White;
                        foreach (var (width, alpha) in new[] { (9f, dark ? 25 : 35), (6f, dark ? 50 : 70), (3.5f, dark ? 110 : 170), (1.8f, dark ? 170 : 255) })
                            using (var pen = new Pen(Color.FromArgb(alpha, halo), width * s) { LineJoin = LineJoin.Round })
                                g.DrawPath(pen, path);
                        fg = dark ? Color.White : (callig ? C(0x061230) : C(0x0B1D4A));
                    }
                    else fg = (style == "glass" || style == "tag") ? C(0x061230) : C(0xFFFFFF, 240);
                    using (var b = new SolidBrush(fg)) g.FillPath(b, path);
                }

                if (callig)
                {
                    var line = new RectangleF(box.X + w * 0.2f, box.Bottom - 3 * s, w * 0.6f, 2 * s);
                    using (var lb = new LinearGradientBrush(line, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
                    {
                        var lime = dark ? C(0xD4FF24) : C(0xA8CC00);
                        lb.InterpolationColors = new ColorBlend { Colors = new[] { Color.FromArgb(0, lime), lime, Color.FromArgb(0, lime) }, Positions = new[] { 0f, 0.5f, 1f } };
                        g.FillRectangle(lb, line);
                    }
                }
            }
            return new BubbleImage { Bitmap = bmp, Pad = pad, Anchor = new Point(pad + (int)(w / 2), pad + (int)(h + tailH)) };
        }

        static GraphicsPath Rounded(RectangleF r, float radius)
        {
            float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            var p = new GraphicsPath();
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static bool SystemIsDark()
        {
            try
            {
                using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"))
                    return k?.GetValue("AppsUseLightTheme") is int v && v == 0;
            }
            catch { return false; }
        }
    }

    /// Tiny click-through, topmost, per-pixel-alpha window. Exists only while its bubble is on screen.
    sealed class LayeredWindow : Form
    {
        public LayeredWindow()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
        }
        protected override bool ShowWithoutActivation => true;
        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ExStyle |= Native.WS_EX_LAYERED | Native.WS_EX_TRANSPARENT | Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE | Native.WS_EX_TOPMOST;
                return cp;
            }
        }

        public void SetBitmap(Bitmap bmp, Point pos, byte alpha)
        {
            IntPtr screenDc = Native.GetDC(IntPtr.Zero), memDc = Native.CreateCompatibleDC(screenDc), hBmp = IntPtr.Zero, old = IntPtr.Zero;
            try
            {
                hBmp = bmp.GetHbitmap(Color.FromArgb(0));
                old = Native.SelectObject(memDc, hBmp);
                var size = new Native.SIZE(bmp.Width, bmp.Height);
                var src = new Native.POINT(0, 0);
                var dst = new Native.POINT(pos.X, pos.Y);
                var blend = Blend(alpha);
                Native.UpdateLayeredWindow(Handle, screenDc, ref dst, ref size, memDc, ref src, 0, ref blend, Native.ULW_ALPHA);
            }
            finally
            {
                Native.ReleaseDC(IntPtr.Zero, screenDc);
                if (hBmp != IntPtr.Zero) { Native.SelectObject(memDc, old); Native.DeleteObject(hBmp); }
                Native.DeleteDC(memDc);
            }
        }

        public void MoveTo(Point pos, byte alpha)
        {
            var dst = new Native.POINT(pos.X, pos.Y);
            var blend = Blend(alpha);
            Native.MoveLayeredWindow(Handle, IntPtr.Zero, ref dst, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, 0, ref blend, Native.ULW_ALPHA);
        }

        public void ShowNoActivate()
        {
            Native.ShowWindow(Handle, Native.SW_SHOWNOACTIVATE);
            Native.SetWindowPos(Handle, Native.HWND_TOPMOST, 0, 0, 0, 0, Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE);
        }

        static Native.BLENDFUNCTION Blend(byte a) =>
            new Native.BLENDFUNCTION { BlendOp = Native.AC_SRC_OVER, BlendFlags = 0, SourceConstantAlpha = a, AlphaFormat = Native.AC_SRC_ALPHA };
    }

    /// Runs the bubbles. One shared timer, and only while at least one bubble is visible — idle CPU stays at 0.
    sealed class BubbleManager
    {
        sealed class Live { public LayeredWindow Win; public BubbleImage Img; public Point Base; public float Scale; public DateTime Start; public int Dur; public bool Fixed; }
        readonly List<Live> live = new List<Live>();
        readonly Timer timer = new Timer { Interval = 15 };
        const int MaxLive = 6;

        public BubbleManager() { timer.Tick += (s, e) => Tick(); }

        public void Show(Point pointer, string text, Settings st)
        {
            float sc = Native.ScaleAt(pointer);
            bool isFixed = st.pos == "fixed";
            var img = BubbleRenderer.Render(text, st.style, st.size, BubbleRenderer.SystemIsDark(), !isFixed, sc);
            Point basePos;
            if (isFixed)
            {
                foreach (var l in live.ToArray()) if (l.Fixed) Finish(l);
                var wa = Screen.FromPoint(pointer).WorkingArea;   // excludes the taskbar
                int m = (int)(20 * sc) - img.Pad, bw = img.Bitmap.Width, bh = img.Bitmap.Height;
                char v = st.corner.Length > 0 ? st.corner[0] : 't', hz = st.corner.Length > 1 ? st.corner[1] : 'r';
                int x = hz == 'l' ? wa.Left + m : hz == 'r' ? wa.Right - bw - m : wa.Left + (wa.Width - bw) / 2;
                int y = v == 'b' ? wa.Bottom - bh - (int)(14 * sc) + img.Pad : wa.Top + (int)(14 * sc) - img.Pad;
                basePos = new Point(x, y);
            }
            else
            {
                basePos = new Point(pointer.X - img.Anchor.X, pointer.Y - (int)(10 * sc) - img.Anchor.Y);
            }

            var win = new LayeredWindow();
            win.SetBitmap(img.Bitmap, new Point(basePos.X, basePos.Y + (int)(4 * sc)), 0);
            win.ShowNoActivate();
            live.Add(new Live { Win = win, Img = img, Base = basePos, Scale = sc, Start = DateTime.UtcNow, Dur = Math.Max(400, st.dur), Fixed = isFixed });
            while (live.Count > MaxLive) Finish(live[0]);
            if (!timer.Enabled) timer.Start();
        }

        static float EaseOut(float t) => 1 - (1 - t) * (1 - t);

        void Tick()
        {
            var now = DateTime.UtcNow;
            foreach (var l in live.ToArray())
            {
                float t = (float)((now - l.Start).TotalMilliseconds / l.Dur);
                if (t >= 1) { Finish(l); continue; }
                // same motion as CSS @keyframes zk-pop: fade in & settle, drift up, fade out
                float dy, a;
                if (t < 0.18f) { float k = EaseOut(t / 0.18f); dy = 4 - 4 * k; a = k; }
                else if (t < 0.75f) { float k = (t - 0.18f) / 0.57f; dy = -6 * k; a = 1; }
                else { float k = EaseOut((t - 0.75f) / 0.25f); dy = -6 - 4 * k; a = 1 - k; }
                l.Win.MoveTo(new Point(l.Base.X, l.Base.Y + (int)Math.Round(dy * l.Scale)), (byte)(255 * Math.Max(0, Math.Min(1, a))));
            }
            if (live.Count == 0) timer.Stop();
        }

        void Finish(Live l)
        {
            live.Remove(l);
            l.Win.Close();
            l.Win.Dispose();
            l.Img.Dispose();
        }
    }
}
