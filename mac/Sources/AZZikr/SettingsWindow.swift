import AppKit
import WebKit

@MainActor
protocol SettingsBridge: AnyObject {
    func settingsChanged()
    func testBubble()
    func resetCount()
    func setLaunchAtLogin(_ on: Bool)
    var launchAtLogin: Bool { get }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow?
    private var web: WKWebView?
    weak var bridge: SettingsBridge?

    var isOpen: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakHandler(self), name: "az")
        let size = NSSize(width: 420, height: 780)
        let web = WebFactory.make(frame: NSRect(origin: .zero, size: size), config: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.autoresizingMask = [.width, .height]

        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "AZ Zikr"
        w.titlebarAppearsTransparent = true
        w.backgroundColor = NSColor(srgbRed: 6/255, green: 18/255, blue: 48/255, alpha: 1)
        w.appearance = NSAppearance(named: .darkAqua)
        w.minSize = NSSize(width: 380, height: 520)
        w.maxSize = NSSize(width: 560, height: 4000)
        w.contentView = web
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        w.setFrameAutosaveName("AZZikrSettings")
        self.window = w
        self.web = web
        WebFactory.load(web, page: "settings.html")
    }

    /// Free the web engine as soon as the window closes, so the app idles with no WebKit processes.
    func windowWillClose(_ notification: Notification) {
        web?.configuration.userContentController.removeScriptMessageHandler(forName: "az")
        web?.stopLoading()
        window?.contentView = nil
        web = nil
        window = nil
    }

    // MARK: native → page
    func pushCount(_ n: Int) { web?.evaluateJavaScript("AZ.setCount(\(n))", completionHandler: nil) }
    func pushEnabled(_ on: Bool) { web?.evaluateJavaScript("AZ.setEnabled(\(on))", completionHandler: nil) }
    private func pushAll() {
        let s = Store.shared
        let js = "AZ.load(\(s.settingsJSON), \(s.currentCount()), \(bridge?.launchAtLogin ?? false))"
        web?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: page → native
    fileprivate func handle(_ body: Any) {
        guard let m = body as? [String: Any], let type = m["type"] as? String else { return }
        switch type {
        case "ready": pushAll()
        case "save":
            if let s = m["settings"] { Store.shared.update(fromJSON: s); bridge?.settingsChanged() }
        case "test": bridge?.testBubble()
        case "reset": bridge?.resetCount(); pushCount(0)
        case "login":
            bridge?.setLaunchAtLogin((m["on"] as? Bool) ?? false)
            web?.evaluateJavaScript("AZ.setLogin(\(bridge?.launchAtLogin ?? false))", completionHandler: nil)
        case "open":
            if let s = m["url"] as? String, let url = URL(string: s),
               ["https", "http", "mailto"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
            }
        default: break
        }
    }

    // Any real navigation away from our local page goes to the default browser instead.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, !url.isFileURL {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    private final class WeakHandler: NSObject, WKScriptMessageHandler {
        weak var owner: SettingsWindowController?
        init(_ o: SettingsWindowController) { owner = o }
        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body
            MainActor.assumeIsolated { owner?.handle(body) }
        }
    }
}
