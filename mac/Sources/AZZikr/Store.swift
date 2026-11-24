import Foundation

struct Zikr: Codable, Equatable {
    var t: String
    var on: Bool
}

/// Mirrors the `S` object in web/settings.html — keep the field names in sync.
struct Settings: Codable, Equatable {
    var enabled = true
    var mode = "click"      // click | sec | nth
    var sec = 5
    var nth = 3
    var dur = 1600          // ms
    var size = 13           // px
    var style = "text"      // text | grad | calm | glass | tag | callig
    var order = "seq"       // seq | rand
    var pos = "cursor"      // cursor | fixed
    var corner = "tr"       // tl tc tr bl bc br
    var azkar: [Zikr] = [
        Zikr(t: "أستغفر الله", on: true), Zikr(t: "سبحان الله", on: true),
        Zikr(t: "الحمد لله", on: true), Zikr(t: "لا إله إلا الله", on: true),
        Zikr(t: "الله أكبر", on: false), Zikr(t: "اللهم صلِّ على محمد", on: false),
        Zikr(t: "سبحان الله وبحمده", on: false), Zikr(t: "لا حول ولا قوة إلا بالله", on: false),
    ]

    init() {}

    // Tolerant decoding: missing keys fall back to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? d.enabled
        mode = (try? c.decode(String.self, forKey: .mode)) ?? d.mode
        sec = (try? c.decode(Int.self, forKey: .sec)) ?? d.sec
        nth = (try? c.decode(Int.self, forKey: .nth)) ?? d.nth
        dur = (try? c.decode(Int.self, forKey: .dur)) ?? d.dur
        size = (try? c.decode(Int.self, forKey: .size)) ?? d.size
        style = (try? c.decode(String.self, forKey: .style)) ?? d.style
        order = (try? c.decode(String.self, forKey: .order)) ?? d.order
        pos = (try? c.decode(String.self, forKey: .pos)) ?? d.pos
        corner = (try? c.decode(String.self, forKey: .corner)) ?? d.corner
        azkar = (try? c.decode([Zikr].self, forKey: .azkar)) ?? d.azkar
        if azkar.isEmpty { azkar = d.azkar }
    }
}

@MainActor
final class Store {
    static let shared = Store()
    private let ud = UserDefaults.standard

    var settings: Settings {
        didSet { persist() }
    }
    private(set) var count: Int = 0
    private var countDay: String = ""

    private init() {
        if let data = ud.data(forKey: "settings"), let s = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = s
        } else {
            settings = Settings()
        }
        count = ud.integer(forKey: "count")
        countDay = ud.string(forKey: "countDay") ?? ""
        rollDay()
    }

    func update(fromJSON obj: Any) {
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return }
        settings = s
    }

    var settingsJSON: String {
        (try? String(data: JSONEncoder().encode(settings), encoding: .utf8)) ?? "{}"
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func rollDay() {
        let t = Store.today()
        if countDay != t { countDay = t; count = 0; saveCount() }
    }

    func increment() { rollDay(); count += 1; saveCount() }
    func resetCount() { count = 0; saveCount() }
    func currentCount() -> Int { rollDay(); return count }

    private func saveCount() {
        ud.set(count, forKey: "count")
        ud.set(countDay, forKey: "countDay")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) { ud.set(data, forKey: "settings") }
    }
}
