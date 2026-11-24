using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;

namespace AZZikr
{
    /// Global left-click listener (low-level mouse hook). The callback only records the point and returns at once,
    /// so it never slows the mouse down. No admin rights needed.
    sealed class MouseHook : IDisposable
    {
        readonly Native.LowLevelMouseProc proc;   // kept alive so the GC never collects the callback
        readonly Action<Point> onLeftDown;
        IntPtr handle;

        public MouseHook(Action<Point> onLeftDown)
        {
            this.onLeftDown = onLeftDown;
            proc = Callback;
            using (var mod = Process.GetCurrentProcess().MainModule)
                handle = Native.SetWindowsHookEx(Native.WH_MOUSE_LL, proc, Native.GetModuleHandle(mod.ModuleName), 0);
        }

        IntPtr Callback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && wParam.ToInt32() == Native.WM_LBUTTONDOWN)
            {
                var info = (Native.MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(Native.MSLLHOOKSTRUCT));
                try { onLeftDown(new Point(info.pt.X, info.pt.Y)); } catch { }
            }
            return Native.CallNextHookEx(handle, nCode, wParam, lParam);
        }

        public void Dispose()
        {
            if (handle != IntPtr.Zero) { Native.UnhookWindowsHookEx(handle); handle = IntPtr.Zero; }
        }
    }
}
