import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// The AZ Creative mark, from brand/Logo.svg (603.62 × 422.01) and brand/icon.svg, drawn as vectors.
enum AZBrand {
    static let viewBox = CGSize(width: 603.62, height: 422.01)
    static let letters = "M78.62,0L.01,84.79v191.38l102.58-66.68v-107.68h87.02v113.64l102.25-32.74V0H78.62ZM189.61,276.28v145.71h102.25v-173.11l-102.25,27.4Z" +
        "M337.41,422.01v-88.85l147.44-231.31h-137.33V.04h256.09v84.78l-145.76,235.75h145.76v101.44h-266.21Z" +
        "M102.62,328.37L102.62,421.97L0,421.97L0,389.78L102.62,328.37Z"
    static let slash = "M408,145.52L291.88,215.06L276.45,224.28L102.62,328.37L0,389.78L0,276.17L102.62,243.3L189.61,215.45L291.88,182.73L408,145.52Z"
    /// brand/icon.svg (408 × 244.27): the slash on its own.
    static let iconViewBox = CGSize(width: 408, height: 244.27)
    static let icon = "M408,0L291.88,69.54L276.45,78.76L102.62,182.86L0,244.27L0,130.66L102.62,97.78L189.61,69.94L291.88,37.21L408,0Z"
    static let navy = Color(hex: 0x01112D)
    static let blue = Color(hex: 0x004ACC)
    static let lime = Color(hex: 0xD4FF24)

    /// Menu-bar template image: the AZ slash from icon.svg, tinted by macOS for light/dark menu bars.
    static func menuBarImage(dimmed: Bool = false) -> NSImage {
        let size = NSSize(width: 22, height: 16)
        let img = NSImage(size: size, flipped: true) { rect in
            let markW: CGFloat = 19, markH = markW * iconViewBox.height / iconViewBox.width
            let target = CGRect(x: (rect.width - markW) / 2, y: (rect.height - markH) / 2, width: markW, height: markH)
            let path = SVGShape(d: icon, viewBox: iconViewBox).path(in: target)
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.withAlphaComponent(dimmed ? 0.35 : 1).cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            return true
        }
        img.isTemplate = true
        return img
    }

    @MainActor
    static func writeAppIcon(to url: URL) {
        let tile = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x23308A), Color(hex: 0x061230)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(RadialGradient(colors: [blue.opacity(0.55), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 470))
            ZStack {
                SVGShape(d: letters, viewBox: viewBox).fill(Color.white)
                SVGShape(d: slash, viewBox: viewBox).fill(lime)
            }
            .aspectRatio(viewBox.width / viewBox.height, contentMode: .fit)
            .frame(width: 540)
        }
        .frame(width: 824, height: 824)
        .frame(width: 1024, height: 1024)
        let r = ImageRenderer(content: tile)
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            print("wrote icon")
        }
    }
}
