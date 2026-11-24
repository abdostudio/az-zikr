import AppKit
import SwiftUI

/// `AZZikr --export-ico <app.ico> <tray.ico>` writes the Windows icons from the same brand vectors,
/// so the Windows build never needs image tools of its own.
@MainActor
enum IconExport {
    static func run(appICO: URL, trayICO: URL, appPNG: URL) {
        guard let big = NSImage(contentsOf: appPNG) else { print("missing \(appPNG.path)"); return }
        writeICO(to: appICO, sizes: [16, 20, 24, 32, 40, 48, 64, 128, 256]) { ctx, s in
            NSGraphicsContext.current?.imageInterpolation = .high
            big.draw(in: NSRect(x: 0, y: 0, width: s, height: s))
            _ = ctx
        }
        // Tray: navy rounded tile + lime AZ slash (icon.svg) — readable on light and dark taskbars.
        writeICO(to: trayICO, sizes: [16, 20, 24, 32, 40, 48, 64]) { ctx, s in
            let r = s * 0.22
            ctx.setFillColor(NSColor(srgbRed: 6/255, green: 18/255, blue: 48/255, alpha: 1).cgColor)
            ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s), cornerWidth: r, cornerHeight: r, transform: nil))
            ctx.fillPath()
            let w = s * 0.78, h = w * AZBrand.iconViewBox.height / AZBrand.iconViewBox.width
            let target = CGRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h)
            // SVG is y-down; flip into the bitmap's y-up space.
            var flip = CGAffineTransform(translationX: 0, y: s).scaledBy(x: 1, y: -1)
            let path = SVGShape(d: AZBrand.icon, viewBox: AZBrand.iconViewBox).path(in: target).cgPath
            if let p = path.copy(using: &flip) { ctx.addPath(p) }
            ctx.setFillColor(NSColor(srgbRed: 212/255, green: 1, blue: 36/255, alpha: 1).cgColor)
            ctx.fillPath()
        }
    }

    private static func render(_ size: Int, _ draw: (CGContext, CGFloat) -> Void) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: size * 4, bitsPerPixel: 32)!
        NSGraphicsContext.saveGraphicsState()
        let g = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = g
        g.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
        draw(g.cgContext, CGFloat(size))
        g.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func writeICO(to url: URL, sizes: [Int], draw: (CGContext, CGFloat) -> Void) {
        var images: [Data] = []
        for s in sizes {
            let rep = render(s, draw)
            if s >= 256 {
                images.append(rep.representation(using: .png, properties: [:])!)
                continue
            }
            // 32-bit DIB: BITMAPINFOHEADER + bottom-up BGRA (straight alpha) + empty AND mask.
            var d = Data()
            func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
            func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
            let maskRow = ((s + 31) / 32) * 4
            u32(40); u32(UInt32(s)); u32(UInt32(s * 2)); u16(1); u16(32); u32(0)
            u32(UInt32(s * s * 4 + maskRow * s)); u32(0); u32(0); u32(0); u32(0)
            let px = rep.bitmapData!
            for y in stride(from: s - 1, through: 0, by: -1) {
                for x in 0..<s {
                    let i = (y * s + x) * 4
                    let a = px[i + 3]
                    func un(_ c: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, Int(c) * 255 / Int(a))) }
                    d.append(contentsOf: [un(px[i + 2]), un(px[i + 1]), un(px[i]), a])
                }
            }
            d.append(Data(count: maskRow * s))
            images.append(d)
        }
        var out = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; out.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; out.append(Data(bytes: &x, count: 2)) }
        u16(0); u16(1); u16(UInt16(sizes.count))
        var offset = 6 + 16 * sizes.count
        for (s, img) in zip(sizes, images) {
            out.append(UInt8(s >= 256 ? 0 : s)); out.append(UInt8(s >= 256 ? 0 : s)); out.append(0); out.append(0)
            u16(1); u16(32); u32(UInt32(img.count)); u32(UInt32(offset))
            offset += img.count
        }
        images.forEach { out.append($0) }
        try? out.write(to: url)
        print("wrote \(url.lastPathComponent) (\(sizes.count) sizes)")
    }
}
