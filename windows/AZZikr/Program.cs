using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace AZZikr
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            using (var mutex = new Mutex(true, "AZZikr.SingleInstance", out bool first))
            {
                if (!first) return;   // already running in the tray
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new TrayApp(args.Contains("--startup")));
            }
        }
    }

    /// Lives in the system tray: listens for clicks, shows bubbles, opens settings on demand.
    sealed class TrayApp : ApplicationContext, ISettingsHost
    {
        const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string RunName = "AZ Zikr";

        readonly NotifyIcon tray;
        readonly MouseHook hook;
        readonly BubbleManager bubbles = new BubbleManager();
        readonly SynchronizationContext ui;
        readonly Random rnd = new Random();
        SettingsForm settingsForm;
        int clicks, seq;
        DateTime lastShown = DateTime.MinValue;

        public Icon AppIcon { get; }

        public TrayApp(bool fromStartup)
        {
            ui = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
            Store.Load();
            AppIcon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            var trayIconPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "tray.ico");

            tray = new NotifyIcon
            {
                Icon = File.Exists(trayIconPath) ? new Icon(trayIconPath, SystemInformation.SmallIconSize) : AppIcon,
                Text = "AZ Zikr",
                Visible = true,
                ContextMenuStrip = new ContextMenuStrip { RightToLeft = RightToLeft.Yes, ShowImageMargin = false }
            };
            tray.ContextMenuStrip.Opening += (s, e) => BuildMenu();
            tray.MouseClick += (s, e) => { if (e.Button == MouseButtons.Left) OpenSettings(); };
            BuildMenu();

            // The hook callback returns immediately; the bubble is drawn right after, on the UI thread.
            hook = new MouseHook(pt => ui.Post(_ => OnClick(pt), null));

            if (Store.IsFirstRun && !fromStartup) OpenSettings();
        }

        // ---------- clicks ----------
        void OnClick(Point pt)
        {
            var s = Store.Settings;
            if (!s.enabled) return;
            clicks++;
            if (s.mode == "nth" && clicks % Math.Max(2, s.nth) != 0) return;
            if (s.mode == "sec" && (DateTime.UtcNow - lastShown).TotalSeconds < Math.Max(1, s.sec)) return;
            lastShown = DateTime.UtcNow;
            bubbles.Show(pt, NextZikr(), s);
            Store.Increment();
            settingsForm?.PushCount(Store.Count);
        }

        string NextZikr()
        {
            var list = Store.Settings.azkar.Where(z => z.on).Select(z => z.t).ToList();
            if (list.Count == 0) return "أستغفر الله";
            if (Store.Settings.order == "rand") return list[rnd.Next(list.Count)];
            return list[(seq++) % list.Count];
        }

        // ---------- ISettingsHost ----------
        public void SettingsChanged() { clicks = 0; lastShown = DateTime.MinValue; }

        public void TestBubble()
        {
            var p = Cursor.Position;
            bubbles.Show(new Point(p.X, p.Y - (int)(24 * Native.ScaleAt(p))), NextZikr(), Store.Settings);
        }

        public void ResetCount() => Store.ResetCount();

        public bool LaunchAtLogin
        {
            get
            {
                using (var k = Registry.CurrentUser.OpenSubKey(RunKey)) return k?.GetValue(RunName) != null;
            }
            set
            {
                using (var k = Registry.CurrentUser.CreateSubKey(RunKey))
                {
                    if (value) k.SetValue(RunName, "\"" + Application.ExecutablePath + "\" --startup");
                    else k.DeleteValue(RunName, false);
                }
            }
        }

        // ---------- tray ----------
        static string Arabic(int n) => string.Concat(n.ToString().Select(c => char.IsDigit(c) ? (char)('٠' + (c - '0')) : c));

        void BuildMenu()
        {
            var m = tray.ContextMenuStrip;
            m.Items.Clear();
            m.Items.Add(new ToolStripMenuItem("ذكرت الله النهارده: " + Arabic(Store.Count)) { Enabled = false });
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add(Store.Settings.enabled ? "إيقاف مؤقت" : "تشغيل", null, (s, e) => ToggleEnabled());
            m.Items.Add("الإعدادات…", null, (s, e) => OpenSettings());
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add("خروج", null, (s, e) => ExitThread());
        }

        void ToggleEnabled()
        {
            var s = Store.Settings;
            s.enabled = !s.enabled;
            Store.Save(s);
            SettingsChanged();
            settingsForm?.PushEnabled(s.enabled);
        }

        void OpenSettings()
        {
            if (settingsForm == null || settingsForm.IsDisposed)
            {
                settingsForm = new SettingsForm(this);
                settingsForm.FormClosed += (s, e) => { settingsForm = null; GC.Collect(); };
                settingsForm.Show();
            }
            if (settingsForm.WindowState == FormWindowState.Minimized) settingsForm.WindowState = FormWindowState.Normal;
            settingsForm.Activate();
        }

        protected override void ExitThreadCore()
        {
            hook.Dispose();
            tray.Visible = false;
            tray.Dispose();
            settingsForm?.Close();
            base.ExitThreadCore();
        }
    }
}
