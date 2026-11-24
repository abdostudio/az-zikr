import SwiftUI

/// Minimal SVG path-data parser (M L H V C S Q T A Z, absolute and relative) → SwiftUI Shape.
/// Copied from AZ Salah. Used to draw the AZ mark from brand/Logo.svg and brand/icon.svg.
struct SVGShape: Shape {
    let d: String
    var viewBox = CGSize(width: 24, height: 24)

    func path(in rect: CGRect) -> Path {
        let base = SVGShape.parse(d)
        let s = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let t = CGAffineTransform(translationX: rect.midX - viewBox.width * s / 2, y: rect.midY - viewBox.height * s / 2).scaledBy(x: s, y: s)
        return base.applying(t)
    }

    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush(); tokens.append(String(ch))
            } else if ch == "-" {
                if let last = num.last, last == "e" { num.append(ch) } else { flush(); num = "-" }
            } else if ch == "." {
                if num.contains(".") && !num.contains("e") { flush() }
                num.append(ch)
            } else if ch == "," || ch == " " || ch == "\n" || ch == "\t" {
                flush()
            } else {
                num.append(ch)
            }
        }
        flush()

        var p = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint? = nil, lastCmd: Character = " "
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        func flag() -> Bool {
            // flags can be packed ("11" in "a2 2 0 1 1 0 4")
            let tok = tokens[i]
            if tok.count > 1, tok.allSatisfy({ $0 == "0" || $0 == "1" }) {
                let f = tok.first == "1"
                tokens[i] = String(tok.dropFirst())
                return f
            }
            i += 1
            return tok == "1"
        }

        while i < tokens.count {
            if let c = tokens[i].first, tokens[i].count == 1, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased().first! {
            case "M":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); start = cur; p.move(to: cur)
                cmd = rel ? "l" : "L"
                lastCtrl = nil
            case "L":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); p.addLine(to: cur); lastCtrl = nil
            case "H":
                cur.x = (rel ? cur.x : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "V":
                cur.y = (rel ? cur.y : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: o.x + n(), y: o.y + n())
                let c2 = CGPoint(x: o.x + n(), y: o.y + n())
                let e = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "S":
                let c1 = (lastCmd == "C" || lastCmd == "S") ? CGPoint(x: 2 * cur.x - (lastCtrl?.x ?? cur.x), y: 2 * cur.y - (lastCtrl?.y ?? cur.y)) : cur
                let c2 = CGPoint(x: o.x + n(), y: o.y + n())
                let e = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: e, control1: c1, control2: c2); lastCtrl = c2; cur = e
            case "Q":
                let c = CGPoint(x: o.x + n(), y: o.y + n())
                let e = CGPoint(x: o.x + n(), y: o.y + n())
                p.addQuadCurve(to: e, control: c); lastCtrl = c; cur = e
            case "T":
                let c = (lastCmd == "Q" || lastCmd == "T") ? CGPoint(x: 2 * cur.x - (lastCtrl?.x ?? cur.x), y: 2 * cur.y - (lastCtrl?.y ?? cur.y)) : cur
                let e = CGPoint(x: o.x + n(), y: o.y + n())
                p.addQuadCurve(to: e, control: c); lastCtrl = c; cur = e
            case "A":
                let rx = n(), ry = n(), rot = n()
                let large = flag(), sweep = flag()
                let e = CGPoint(x: o.x + n(), y: o.y + n())
                addArc(&p, from: cur, to: e, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = e; lastCtrl = nil
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
            default:
                i += 1
            }
            lastCmd = Character(cmd.uppercased())
        }
        return p
    }

    /// SVG endpoint arc → cubic Béziers.
    private static func addArc(_ p: inout Path, from a: CGPoint, to b: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat,
                               rotation: CGFloat, large: Bool, sweep: Bool) {
        if a == b { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { p.addLine(to: b); return }
        let phi = rotation * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { rx *= sqrt(lam); ry *= sqrt(lam) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var co = sqrt(max(0, num / den))
        if large == sweep { co = -co }
        let cx1 = co * rx * y1 / ry, cy1 = -co * ry * x1 / rx
        let cx = cosP * cx1 - sinP * cy1 + (a.x + b.x) / 2
        let cy = sinP * cx1 + cosP * cy1 + (a.y + b.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let s: CGFloat = (ux * vy - uy * vx) < 0 ? -1 : 1
            let d = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
            return s * acos(min(1, max(-1, d)))
        }
        let t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segs = Int(ceil(abs(dt) / (.pi / 2)))
        let step = dt / CGFloat(segs)
        let k = 4 / 3 * tan(step / 4)
        func pt(_ t: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(t) * cosP - ry * sin(t) * sinP, y: cy + rx * cos(t) * sinP + ry * sin(t) * cosP)
        }
        func dv(_ t: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(t) * cosP - ry * cos(t) * sinP, y: -rx * sin(t) * sinP + ry * cos(t) * cosP)
        }
        var t = t1
        for _ in 0..<segs {
            let p0 = pt(t), p3 = pt(t + step), d0 = dv(t), d3 = dv(t + step)
            p.addCurve(to: p3, control1: CGPoint(x: p0.x + k * d0.x, y: p0.y + k * d0.y),
                       control2: CGPoint(x: p3.x - k * d3.x, y: p3.y - k * d3.y))
            t += step
        }
    }
}

