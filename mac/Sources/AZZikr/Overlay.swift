import AppKit
import SwiftUI
import WebKit

/// Native bubbles: each one is a tiny transparent, click-through panel that lives only while it is on screen.
/// Nothing stays in memory between clicks (no full-screen windows, no web engine) — the app idles at ~0% CPU.
@MainActor
final class OverlayManager {
    private var live: [NSPanel] = []
    private weak var fixedPanel: NSPanel?
    private static let maxLive = 6

    /// `point` is in global AppKit screen coordinates (origin bottom-left of the main screen).
    func show(at point: NSPoint, text: String, settings s: Settings) {
        let panel = makePanel(BubbleView(text: text, style: s.style, size: CGFloat(s.size), dark: isDark, tail: true))
        let size = panel.frame.size
        // The tail tip (bottom-centre of the bubble, inside the padding) sits 10pt above the pointer.
        let origin = NSPoint(x: point.x - size.width / 2, y: point.y + 10 - BubbleView.pad)
        animate(panel, from: origin, duration: Double(s.dur) / 1000)
    }

    /// Fixed spot on the screen the pointer is on, clear of the menu bar and Dock. One at a time.
    func showFixed(onScreenAt point: NSPoint, text: String, settings s: Settings) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main
        guard let v = screen?.visibleFrame else { return }
        fixedPanel?.orderOut(nil)
        let panel = makePanel(BubbleView(text: text, style: s.style, size: CGFloat(s.size), dark: isDark, tail: false))
        fixedPanel = panel
        let size = panel.frame.size
        let m: CGFloat = 14 - BubbleView.pad + 6
        let c = Array(s.corner)
        let h: Character = c.count > 1 ? c[1] : "r"
        let x: CGFloat = h == "l" ? v.minX + m : h == "r" ? v.maxX - size.width - m : v.midX - size.width / 2
        let y: CGFloat = c.first == "b" ? v.minY + m : v.maxY - size.height - m
        animate(panel, from: NSPoint(x: x, y: y), duration: Double(s.dur) / 1000)
    }

    private var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func makePanel(_ view: BubbleView) -> NSPanel {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .screenSaver
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isReleasedWhenClosed = false
        p.contentView = host
        return p
    }

    /// Same motion as the design: fade in while settling, drift up gently, fade out.
    private func animate(_ panel: NSPanel, from origin: NSPoint, duration d: Double) {
        live.append(panel)
        if live.count > Self.maxLive { let old = live.removeFirst(); old.orderOut(nil) }
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y - 4))
        panel.orderFrontRegardless()
        func move(_ dy: CGFloat, alpha: CGFloat, _ t: Double, then: (@MainActor () -> Void)?) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = t
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = alpha
                panel.animator().setFrameOrigin(NSPoint(x: origin.x, y: origin.y + dy))
            }, completionHandler: { MainActor.assumeIsolated { then?() } })
        }
        move(0, alpha: 1, d * 0.18) {
            move(6, alpha: 1, d * 0.57) {
                move(10, alpha: 0, d * 0.25) { [weak self] in
                    panel.orderOut(nil)
                    panel.contentView = nil
                    self?.live.removeAll { $0 === panel }
                }
            }
        }
    }
}

/// The six bubble styles, matching web/bubble.css.
struct BubbleView: View {
    static let pad: CGFloat = 10   // room for shadow / halo around the bubble
    let text: String
    let style: String
    let size: CGFloat
    let dark: Bool
    let tail: Bool

    var body: some View {
        content
            .padding(Self.pad)
            .fixedSize()
            .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder private var content: some View {
        let halo = dark ? Color.black.opacity(0.55) : Color.white
        switch style {
        case "text":
            Text(text).font(.system(size: size, weight: .semibold))
                .foregroundColor(dark ? .white : Color(hex: 0x0B1D4A))
                .shadow(color: halo, radius: 2).shadow(color: halo, radius: 5).shadow(color: halo, radius: 8)
                .padding(.horizontal, 4).padding(.vertical, 2)
        case "callig":
            Text(text).font(.custom("Amiri Quran", size: size * 1.35))
                .foregroundColor(dark ? .white : Color(hex: 0x061230))
                .shadow(color: halo, radius: 3).shadow(color: halo, radius: 7)
                .padding(.horizontal, 4).padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, dark ? AZBrand.lime : Color(hex: 0xA8CC00), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(height: 2).clipShape(Capsule()).padding(.horizontal, 20)
                }
        case "tag":
            pill(fg: Color(hex: 0x061230), tailColor: .white) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white)
                    .overlay(alignment: .trailing) { Rectangle().fill(AZBrand.blue).frame(width: 3) }   // RTL start edge
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .shadow(color: Color(hex: 0x061230).opacity(0.14), radius: 5, y: 3)
        case "glass":
            pill(fg: Color(hex: 0x061230), tailColor: Color.white.opacity(0.86)) {
                Capsule().fill(Color.white.opacity(0.86)).overlay(Capsule().stroke(Color.white, lineWidth: 1))
            }
            .shadow(color: Color(hex: 0x061230).opacity(0.12), radius: 7, y: 4)
        case "grad":
            pill(fg: .white.opacity(0.95), tailColor: Color(hex: 0x0C205F, alpha: 0.92)) {
                Capsule().fill(LinearGradient(colors: [Color(hex: 0x061230, alpha: 0.92), Color(hex: 0x14349A, alpha: 0.9)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .shadow(color: Color(hex: 0x061230).opacity(0.18), radius: 6, y: 4)
        default: // calm
            pill(fg: .white.opacity(0.92), tailColor: Color(hex: 0x08163C, alpha: 0.88)) {
                Capsule().fill(Color(hex: 0x08163C, alpha: 0.88)).overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .shadow(color: Color(hex: 0x061230).opacity(0.18), radius: 6, y: 4)
        }
    }

    private func pill<B: View>(fg: Color, tailColor: Color, @ViewBuilder bg: () -> B) -> some View {
        Text(text).font(.system(size: size, weight: .medium)).foregroundColor(fg)
            .padding(.horizontal, 11).padding(.top, 5).padding(.bottom, 6)
            .background(bg())
            .overlay(alignment: .bottom) {
                if tail {
                    RoundedRectangle(cornerRadius: 2).fill(tailColor).frame(width: 8, height: 8)
                        .rotationEffect(.degrees(45)).offset(y: 4)
                }
            }
    }
}

func jsString(_ s: String) -> String {
    let data = try? JSONSerialization.data(withJSONObject: [s])
    let arr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
    return String(arr.dropFirst().dropLast())
}

@MainActor
enum WebFactory {
    static var webDir: URL {
        if let env = ProcessInfo.processInfo.environment["AZZIKR_WEB"] { return URL(fileURLWithPath: env) }
        return Bundle.main.resourceURL!.appendingPathComponent("web")
    }

    static func registerFonts() {
        CTFontManagerRegisterFontsForURL(webDir.appendingPathComponent("fonts/AmiriQuran.ttf") as CFURL, .process, nil)
    }

    static func make(frame: NSRect, config: WKWebViewConfiguration? = nil) -> WKWebView {
        let web = WKWebView(frame: frame, configuration: config ?? WKWebViewConfiguration())
        web.setValue(false, forKey: "drawsBackground")
        web.underPageBackgroundColor = .clear
        return web
    }

    static func load(_ web: WKWebView, page: String) {
        web.loadFileURL(webDir.appendingPathComponent(page), allowingReadAccessTo: webDir)
    }
}
