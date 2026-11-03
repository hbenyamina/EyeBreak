import AppKit
import SwiftUI

/// A named look for the End of Shift widget: one surface per shift state, an ink that
/// reads on each, a signal colour, and an accent for the shift's countdown inside the app.
///
/// All thirteen sit at OKLCH chroma 0.004–0.056 — a fraction of the saturation this palette
/// started with. Fully saturated colour at the edge of the sRGB gamut looks cheap on a
/// desktop and fights the wallpaper behind it; these read as materials instead. Each
/// tone is a single hue, and a state is told apart by lightness rather than by a shift
/// across the hue wheel.
///
/// Surfaces are solid (EyeBreak draws no gradients) and deep enough that a near-white ink
/// lands at 8–13:1, leaving room for the two quieter text levels `Surface` derives
/// beneath it. The values were generated from OKLCH targets and are guarded by the
/// contrast tests in `Tests/`.
struct ShiftTheme: Identifiable, Hashable {

    struct Surface: Hashable {
        let color: Color
        /// Headline text: the countdown, the times.
        let ink: Color
        /// Labels and footers. Mixed toward the surface, but stopped at 6:1.
        let inkSoft: Color
        /// The quietest line on the tile. Stopped at 4.7:1 — still AA for small text.
        let inkFaint: Color
        let track: Color

        init(color: Color, ink: Color) {
            self.color = color
            self.ink = ink

            // Light text on a dark surface rasterises thinner than its nominal colour,
            // and the loss is proportional, not fixed: measuring the drawn pixels gave
            // roughly 0.72 of the nominal ratio (nominal 5.30 rendered 3.71). Dark text
            // on a light surface renders slightly heavier and needs no allowance. So
            // these floors are raised only in the direction that loses contrast, by
            // enough that 4.5 survives rasterising.
            let lightOnDark = Contrast.inkIsLighterThanSurface(ink, [color])
            let softFloor = lightOnDark ? 7.6 : 6.0
            let faintFloor = lightOnDark ? 6.5 : Contrast.smallText + 0.2

            // Derived rather than hand-picked, so a new theme cannot ship unreadable
            // secondary text: the surface itself decides how far the mix can go.
            self.inkSoft = Contrast.muted(ink, over: [color], minimumRatio: softFloor)
            self.inkFaint = Contrast.muted(ink, over: [color], minimumRatio: faintFloor)
            self.track = ink.opacity(0.28)
        }
    }

    /// Two kinds of look. Tones are a single hue carried across all three states.
    /// Workplaces are a muted ground plus one functional accent, the way a real room
    /// has a wall colour and a signal colour — and two of them sit in a pale register,
    /// so the set isn't six variations of dark.
    enum Family: String, CaseIterable, Identifiable, Hashable {
        case tone
        case workplace

        var id: String { rawValue }

        var label: String {
            switch self {
            case .tone: return String(shared: "Tones")
            case .workplace: return String(shared: "Workplaces")
            }
        }
    }

    let id: String
    let name: String
    let family: Family
    /// A shift under way.
    let working: Surface
    /// A shift still ahead today.
    let ahead: Surface
    /// Evenings, weekends, days off.
    let off: Surface
    /// The theme's signal colour; white text has to read on it.
    let tint: Color
    /// The shift's countdown in the app (menu, Settings), in light and dark appearance.
    let heroAccent: Color

    func surface(for phase: ShiftStatus.Phase?) -> Surface {
        switch phase {
        case .onShift: return working
        case .beforeShift: return ahead
        case .offDuty, .none: return off
        }
    }

    static let defaultID = "slate"

    static func named(_ id: String?) -> ShiftTheme {
        all.first { $0.id == id } ?? all[0]
    }

    static let all: [ShiftTheme] = [slate, clay, sage, ochre, plum, graphite,
                                    ward, warehouse, nightdesk, workshop, line, control, greenhouse]

    static func all(in family: Family) -> [ShiftTheme] {
        all.filter { $0.family == family }
    }

    // MARK: The themes

    /// Cool blue-grey, the default.
    static let slate = ShiftTheme(
        id: "slate", name: String(shared: "Slate"), family: .tone,
        working: Surface(color: Color(rgb: 0x20414F), ink: Color(rgb: 0xEEF5F8)),
        ahead:   Surface(color: Color(rgb: 0x213745), ink: Color(rgb: 0xEEF5F8)),
        off:     Surface(color: Color(rgb: 0x0C242B), ink: Color(rgb: 0xEEF5F8)),
        tint: Color(rgb: 0x31586A),
        heroAccent: Color(light: 0x325B6D, dark: 0xACC9D7))

    /// Warm earth, the colour of unglazed pottery.
    static let clay = ShiftTheme(
        id: "clay", name: String(shared: "Clay"), family: .tone,
        working: Surface(color: Color(rgb: 0x553225), ink: Color(rgb: 0xFAF1EE)),
        ahead:   Surface(color: Color(rgb: 0x472D20), ink: Color(rgb: 0xFAF1EE)),
        off:     Surface(color: Color(rgb: 0x311915), ink: Color(rgb: 0xFAF1EE)),
        tint: Color(rgb: 0x714637),
        heroAccent: Color(light: 0x754839, dark: 0xDEBBAF))

    /// Muted green, the quietest of the six.
    static let sage = ShiftTheme(
        id: "sage", name: String(shared: "Sage"), family: .tone,
        working: Surface(color: Color(rgb: 0x264338), ink: Color(rgb: 0xEFF5F2)),
        ahead:   Surface(color: Color(rgb: 0x223A33), ink: Color(rgb: 0xEFF5F2)),
        off:     Surface(color: Color(rgb: 0x14251C), ink: Color(rgb: 0xEFF5F2)),
        tint: Color(rgb: 0x395B4D),
        heroAccent: Color(light: 0x3A5E50, dark: 0xB1CBC0))

    /// Dry olive-gold, like aged paper under lamplight.
    static let ochre = ShiftTheme(
        id: "ochre", name: String(shared: "Ochre"), family: .tone,
        working: Surface(color: Color(rgb: 0x483A1B), ink: Color(rgb: 0xF6F3ED)),
        ahead:   Surface(color: Color(rgb: 0x3B341B), ink: Color(rgb: 0xF6F3ED)),
        off:     Surface(color: Color(rgb: 0x2A1E0C), ink: Color(rgb: 0xF6F3ED)),
        tint: Color(rgb: 0x61502C),
        heroAccent: Color(light: 0x64532C, dark: 0xD0C3A7))

    /// Dusky violet, warm at the edges.
    static let plum = ShiftTheme(
        id: "plum", name: String(shared: "Plum"), family: .tone,
        working: Surface(color: Color(rgb: 0x47344B), ink: Color(rgb: 0xF6F2F7)),
        ahead:   Surface(color: Color(rgb: 0x3F2D3E), ink: Color(rgb: 0xF6F2F7)),
        off:     Surface(color: Color(rgb: 0x261C2C), ink: Color(rgb: 0xF6F2F7)),
        tint: Color(rgb: 0x604965),
        heroAccent: Color(light: 0x634B69, dark: 0xCFBDD3))

    /// Almost neutral, for a desktop that shouldn't shout.
    static let graphite = ShiftTheme(
        id: "graphite", name: String(shared: "Graphite"), family: .tone,
        working: Surface(color: Color(rgb: 0x3A3C3F), ink: Color(rgb: 0xF3F3F4)),
        ahead:   Surface(color: Color(rgb: 0x333437), ink: Color(rgb: 0xF3F3F4)),
        off:     Surface(color: Color(rgb: 0x1F2123), ink: Color(rgb: 0xF3F3F4)),
        tint: Color(rgb: 0x505356),
        heroAccent: Color(light: 0x525659, dark: 0xC2C4C7))

    // MARK: Workplaces

    /// Clinical porcelain, cool and bright.
    static let ward = ShiftTheme(
        id: "ward", name: String(shared: "Ward"), family: .workplace,
        working: Surface(color: Color(rgb: 0xD3E1E4), ink: Color(rgb: 0x192729)),
        ahead:   Surface(color: Color(rgb: 0xE0EAED), ink: Color(rgb: 0x192729)),
        off:     Surface(color: Color(rgb: 0xBECED0), ink: Color(rgb: 0x192729)),
        tint: Color(rgb: 0x315E73),
        heroAccent: Color(light: 0x345B6E, dark: 0xA9CADA))

    /// Poured concrete under daylight panels.
    static let warehouse = ShiftTheme(
        id: "warehouse", name: String(shared: "Warehouse"), family: .workplace,
        working: Surface(color: Color(rgb: 0xDADFE2), ink: Color(rgb: 0x202528)),
        ahead:   Surface(color: Color(rgb: 0xE5E8EB), ink: Color(rgb: 0x202528)),
        off:     Surface(color: Color(rgb: 0xC6CCCF), ink: Color(rgb: 0x202528)),
        tint: Color(rgb: 0x3C5D70),
        heroAccent: Color(light: 0x3C5A6B, dark: 0xAFC8D8))

    /// Deep after-hours blue, the darkest of the set.
    static let nightdesk = ShiftTheme(
        id: "nightdesk", name: String(shared: "Night Desk"), family: .workplace,
        working: Surface(color: Color(rgb: 0x293E53), ink: Color(rgb: 0xEFF4F9)),
        ahead:   Surface(color: Color(rgb: 0x293547), ink: Color(rgb: 0xEFF4F9)),
        off:     Surface(color: Color(rgb: 0x12232F), ink: Color(rgb: 0xEFF4F9)),
        tint: Color(rgb: 0x3B5B7B),
        heroAccent: Color(light: 0x3C5875, dark: 0xAFC7E1))

    /// Oiled timber with brass fittings.
    static let workshop = ShiftTheme(
        id: "workshop", name: String(shared: "Workshop"), family: .workplace,
        working: Surface(color: Color(rgb: 0x4C362D), ink: Color(rgb: 0xF7F2F0)),
        ahead:   Surface(color: Color(rgb: 0x403027), ink: Color(rgb: 0xF7F2F0)),
        off:     Surface(color: Color(rgb: 0x2B1D18), ink: Color(rgb: 0xF7F2F0)),
        tint: Color(rgb: 0x6E5322),
        heroAccent: Color(light: 0x695126, dark: 0xD6C19E))

    /// Factory-floor green with a hazard-amber accent.
    static let line = ShiftTheme(
        id: "line", name: String(shared: "Line"), family: .workplace,
        working: Surface(color: Color(rgb: 0x334033), ink: Color(rgb: 0xF1F4F1)),
        ahead:   Surface(color: Color(rgb: 0x2C382F), ink: Color(rgb: 0xF1F4F1)),
        off:     Surface(color: Color(rgb: 0x1C231A), ink: Color(rgb: 0xF1F4F1)),
        tint: Color(rgb: 0x72511E),
        heroAccent: Color(light: 0x6D4F23, dark: 0xDAC09C))

    /// Charcoal console, dim amber indicators.
    static let control = ShiftTheme(
        id: "control", name: String(shared: "Control"), family: .workplace,
        working: Surface(color: Color(rgb: 0x3A3C3F), ink: Color(rgb: 0xF3F3F4)),
        ahead:   Surface(color: Color(rgb: 0x333436), ink: Color(rgb: 0xF3F3F4)),
        off:     Surface(color: Color(rgb: 0x1F2122), ink: Color(rgb: 0xF3F3F4)),
        tint: Color(rgb: 0x734F2B),
        heroAccent: Color(light: 0x6E4E2E, dark: 0xDBBEA3))

    /// A greenhouse in the morning: deep leaf green with a terracotta-pot signal; goes with
    /// the Garden app theme.
    static let greenhouse = ShiftTheme(
        id: "greenhouse", name: String(shared: "Greenhouse"), family: .workplace,
        working: Surface(color: Color(rgb: 0x2A4A31), ink: Color(rgb: 0xF0F5EE)),
        ahead:   Surface(color: Color(rgb: 0x2B4337), ink: Color(rgb: 0xF0F5EE)),
        off:     Surface(color: Color(rgb: 0x15241A), ink: Color(rgb: 0xF0F5EE)),
        tint: Color(rgb: 0xA4502F),
        heroAccent: Color(light: 0x3B6B44, dark: 0xB7D6B2))
}

extension Color {
    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }

    /// A colour that follows the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                           green: CGFloat((rgb >> 8) & 0xFF) / 255,
                           blue: CGFloat(rgb & 0xFF) / 255,
                           alpha: 1)
        })
    }
}
