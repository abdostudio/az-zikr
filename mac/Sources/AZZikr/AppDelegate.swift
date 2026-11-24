import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SettingsBridge {
    private var overlay: OverlayManager!
    private let settingsWC = SettingsWindowController()
    private var statusItem: NSStatusItem!
    private var monitors: [Any] = []

    // click-rhythm state
    private var clicks = 0
    private var lastShown = Date.distantPast
    private var seqIndex = 0

    private let arabic: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ar_EG")
        return f
    }()

    func applicationDidFinishLaunching(_ note: Notification) {
        WebFactory.registerFonts()
        overlay = OverlayManager()
        settingsWC.bridge = self
        setupStatusItem()

        // Global monitor = clicks in other apps (no special permission needed for mouse-down).
        // Local monitor = clicks inside our own settings window.
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { _ in
            MainActor.assumeIsolated { self.onClick() }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown], handler: { e in
            MainActor.assumeIsolated { self.onClick() }
            return e
        }) { monitors.append(l) }

        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            UserDefaults.standard.set(true, forKey: "didOnboard")
            settingsWC.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWC.show()
        return true
    }

    // MARK: clicks

    private func onClick() {
        let s = Store.shared.settings
        guard s.enabled else { return }
        clicks += 1
        switch s.mode {
        case "nth": guard clicks % max(2, s.nth) == 0 else { return }
        case "sec":
            guard Date().timeIntervalSince(lastShown) >= Double(max(1, s.sec)) else { return }
        default: break
        }
        lastShown = Date()
        showBubble(at: NSEvent.mouseLocation)
    }

    private func nextZikr() -> String {
        let list = Store.shared.settings.azkar.filter(\.on).map(\.t)
        guard !list.isEmpty else { return "أستغفر الله" }
        if Store.shared.settings.order == "rand" { return list.randomElement()! }
        defer { seqIndex += 1 }
        return list[seqIndex % list.count]
    }

    private func showBubble(at p: NSPoint) {
        present(at: p, text: nextZikr())
        Store.shared.increment()
        if settingsWC.isOpen { settingsWC.pushCount(Store.shared.count) }
    }

    private func present(at p: NSPoint, text: String) {
        let s = Store.shared.settings
        if s.pos == "fixed" { overlay.showFixed(onScreenAt: p, text: text, settings: s) }
        else { overlay.show(at: p, text: text, settings: s) }
    }

    // MARK: SettingsBridge

    func settingsChanged() {
        clicks = 0
        lastShown = .distantPast
        refreshStatusIcon()
    }

    func testBubble() {
        // Show it just above the pointer, even if paused or throttled.
        let p = NSEvent.mouseLocation
        present(at: NSPoint(x: p.x, y: p.y + 24), text: nextZikr())
    }

    func resetCount() { Store.shared.resetCount() }

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("AZZikr: login item change failed: \(error)")
        }
    }

    // MARK: menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "AZ Zikr"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        statusItem.button?.image = AZBrand.menuBarImage(dimmed: !Store.shared.settings.enabled)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = Store.shared
        let n = arabic.string(from: NSNumber(value: s.currentCount())) ?? "\(s.count)"
        let header = NSMenuItem(title: "ذكرت الله النهارده: \(n)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: s.settings.enabled ? "إيقاف مؤقت" : "تشغيل",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let settings = NSMenuItem(title: "الإعدادات…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "خروج", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func toggleEnabled() {
        Store.shared.settings.enabled.toggle()
        settingsChanged()
        settingsWC.pushEnabled(Store.shared.settings.enabled)
    }

    @objc private func openSettings() { settingsWC.show() }
}
