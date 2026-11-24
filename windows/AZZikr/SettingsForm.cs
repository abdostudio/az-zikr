using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace AZZikr
{
    interface ISettingsHost
    {
        void SettingsChanged();
        void TestBubble();
        void ResetCount();
        bool LaunchAtLogin { get; set; }
        Icon AppIcon { get; }
    }

    /// Hosts web/settings.html in WebView2. The web engine only runs while this window is open;
    /// closing the window disposes it, so the app goes back to idling with no browser processes.
    sealed class SettingsForm : Form
    {
        const string Host = "azzikr.local";
        readonly ISettingsHost host;
        readonly WebView2 web;

        public SettingsForm(ISettingsHost host)
        {
            this.host = host;
            Text = "AZ Zikr";
            Icon = host.AppIcon;
            BackColor = Color.FromArgb(6, 18, 48);
            StartPosition = FormStartPosition.CenterScreen;
            float sc = DeviceDpi / 96f;
            ClientSize = new Size((int)(420 * sc), (int)(Math.Min(820, Screen.FromPoint(Cursor.Position).WorkingArea.Height / sc - 60) * sc));
            MinimumSize = new Size((int)(380 * sc), (int)(520 * sc));
            web = new WebView2 { Dock = DockStyle.Fill, DefaultBackgroundColor = BackColor };
            Controls.Add(web);
            Load += async (s, e) => await InitAsync();
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            int on = 1;   // dark title bar on Windows 10 20H1+ / 11, matching the navy UI
            try { Native.DwmSetWindowAttribute(Handle, 20, ref on, 4); } catch { }
        }

        async System.Threading.Tasks.Task InitAsync()
        {
            try
            {
                var data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AZ Zikr", "WebView2");
                var env = await CoreWebView2Environment.CreateAsync(null, data);
                await web.EnsureCoreWebView2Async(env);
            }
            catch (WebView2RuntimeNotFoundException)
            {
                if (MessageBox.Show("شاشة الإعدادات محتاجة Microsoft Edge WebView2 (موجود في أغلب أجهزة ويندوز 10 و 11).\nتحب تفتح صفحة التحميل؟",
                        "AZ Zikr", MessageBoxButtons.YesNo, MessageBoxIcon.Information, MessageBoxDefaultButton.Button1,
                        MessageBoxOptions.RtlReading | MessageBoxOptions.RightAlign) == DialogResult.Yes)
                    OpenExternal("https://go.microsoft.com/fwlink/p/?LinkId=2124703");
                Close();
                return;
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "AZ Zikr");
                Close();
                return;
            }

            var core = web.CoreWebView2;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.AreDevToolsEnabled = false;
            core.Settings.IsZoomControlEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.AreBrowserAcceleratorKeysEnabled = false;
            core.SetVirtualHostNameToFolderMapping(Host, Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "web"),
                                                   CoreWebView2HostResourceAccessKind.Allow);
            core.WebMessageReceived += OnMessage;
            core.NewWindowRequested += (s, e) => { e.Handled = true; OpenExternal(e.Uri); };
            core.NavigationStarting += (s, e) =>
            {
                if (!e.Uri.StartsWith("https://" + Host + "/", StringComparison.OrdinalIgnoreCase)) { e.Cancel = true; OpenExternal(e.Uri); }
            };
            core.Navigate("https://" + Host + "/settings.html");
        }

        void OnMessage(object sender, CoreWebView2WebMessageReceivedEventArgs e)
        {
            var m = Store.Parse(e.WebMessageAsJson);
            if (m == null || !m.TryGetValue("type", out var t)) return;
            switch (t as string)
            {
                case "ready": PushAll(); break;
                case "save":
                    if (m.TryGetValue("settings", out var s) && s != null) { Store.Save(Store.FromObject(s)); host.SettingsChanged(); }
                    break;
                case "test": host.TestBubble(); break;
                case "reset": host.ResetCount(); PushCount(0); break;
                case "login":
                    host.LaunchAtLogin = m.TryGetValue("on", out var on) && on is bool b && b;
                    Exec("AZ.setLogin(" + (host.LaunchAtLogin ? "true" : "false") + ")");
                    break;
                case "open":
                    if (m.TryGetValue("url", out var u) && u is string url) OpenExternal(url);
                    break;
            }
        }

        void PushAll() =>
            Exec("AZ.load(" + Store.SettingsJson + ", " + Store.Count + ", " + (host.LaunchAtLogin ? "true" : "false") + ")");

        public void PushCount(int n) => Exec("AZ.setCount(" + n + ")");
        public void PushEnabled(bool on) => Exec("AZ.setEnabled(" + (on ? "true" : "false") + ")");

        void Exec(string js)
        {
            try { web.CoreWebView2?.ExecuteScriptAsync(js); } catch { }
        }

        static void OpenExternal(string url)
        {
            if (Uri.TryCreate(url, UriKind.Absolute, out var u) && (u.Scheme == "https" || u.Scheme == "http" || u.Scheme == "mailto"))
                try { Process.Start(new ProcessStartInfo(u.AbsoluteUri) { UseShellExecute = true }); } catch { }
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            base.OnFormClosed(e);
            web.Dispose();
        }
    }
}
