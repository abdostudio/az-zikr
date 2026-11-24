import AppKit
import SwiftUI
import WebKit

/// `AZZikr --snapshot <dir>` renders the real views offscreen to PNGs, for design review
/// without screen-recording permission: the settings window, every bubble style (light + dark), and the menu-bar icon.
@MainActor
enum Snapshots {
    private static var keep: [AnyObject] = []

    static func run(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        WebFactory.registerFonts()
        Task { @MainActor in
            await settingsShot(to: dir.appendingPathComponent("settings.png"))
            let styles = ["text", "grad", "calm", "glass", "tag", "callig"]
            let texts = ["أستغفر الله", "سبحان الله", "الحمد لله", "لا إله إلا الله", "الله أكبر", "سبحان الله وبحمده"]
            for dark in [false, true] {
                let grid = VStack(spacing: 30) {
                    ForEach(0..<2) { row in
                        HStack(spacing: 40) {
                            ForEach(0..<3) { col in
                                let i = row * 3 + col
                                VStack(spacing: 2) {
                                    BubbleView(text: texts[i], style: styles[i], size: 13, dark: dark, tail: true)
                                    Text(styles[i]).font(.system(size: 9)).foregroundColor(.gray)
                                }.frame(width: 150)
                            }
                        }
                    }
                }
                .padding(30)
                .background(dark ? Color(hex: 0x1E1E24) : Color(hex: 0xE3E8F4))
                .environment(\.colorScheme, dark ? .dark : .light)
                png(grid, to: dir.appendingPathComponent(dark ? "bubbles-dark.png" : "bubbles-light.png"))
            }
            let icon = AZBrand.menuBarImage()
            if let tiff = icon.tiffRepresentation, let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? data.write(to: dir.appendingPathComponent("menubar-icon.png"))
            }
            print("snapshots written to \(dir.path)")
            exit(0)
        }
    }

    private static func png<V: View>(_ view: V, to url: URL) {
        let r = ImageRenderer(content: view)
        r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
            print("wrote \(url.lastPathComponent)")
        }
    }

    private static func settingsShot(to url: URL) async {
        let size = NSSize(width: 420, height: 1320)
        let w = NSWindow(contentRect: NSRect(x: -5000, y: -5000, width: size.width, height: size.height),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .darkAqua)
        let web = WebFactory.make(frame: NSRect(origin: .zero, size: size))
        w.contentView = web
        w.orderFrontRegardless()
        keep.append(w)
        WebFactory.load(web, page: "settings.html")
        for _ in 0..<60 where web.isLoading { try? await Task.sleep(nanoseconds: 50_000_000) }
        try? await Task.sleep(nanoseconds: 500_000_000)
        _ = try? await web.evaluateJavaScript("document.querySelector('#pos [data-p=fixed]').click()")
        try? await Task.sleep(nanoseconds: 200_000_000)
        let cfg = WKSnapshotConfiguration()
        cfg.rect = NSRect(origin: .zero, size: size)
        if let img = try? await web.takeSnapshot(configuration: cfg), let tiff = img.tiffRepresentation,
           let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
            print("wrote \(url.lastPathComponent)")
        }
    }
}
