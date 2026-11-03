import SwiftUI

// MARK: - App Themes
/// The looks the whole app can wear: window, menu, break screens and the Rhythm widget.
/// Each keeps the same jobs for its colours — one for the eyes, one for water, a red for
/// the dry-eye warning only — and its own neutral ground. Solid colours only.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    /// Violet for the eyes, clear aqua for water.
    case classic
    /// Leaf green for the eyes, rain-water blue, on linen and soil.
    case garden

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return String(shared: "Violet & Aqua")
        case .garden: return String(shared: "Garden")
        }
    }

    var detail: String {
        switch self {
        case .classic: return String(shared: "EyeBreak's own colours: violet for your eyes, clear aqua for water.")
        case .garden: return String(shared: "A kitchen garden in the morning: leaf green for your eyes, rain-water blue, on linen and soil.")
        }
    }
}

extension Color {
    /// A colour that follows the system appearance, from two colours.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }
}

/// Every colour a theme decides.
struct ThemeColors {
    struct Ramp {
        let light, bright, accent, deep, dark: Color
    }

    /// Neutrals for the window, popover and widgets.
    struct Page {
        let paper, ink, secondaryInk, hairline, wash: Color
    }

    let eyes: Ramp
    let water: Ramp
    /// Text on the bright water fill, where white would fail.
    let waterInk: Color
    /// Reserved red (once the dry-eye warning's).
    let alert: Color
    let page: Page
    /// Laid over the full-screen frost behind a break, and behind a full-screen water reminder.
    let eyesBackdrop: Color
    let waterBackdrop: Color
    /// Starting hexes for a custom reminder theme.
    let eyesHex, waterHex, eyesLightHex, waterLightHex, eyesBackdropHex, waterBackdropHex: String

    static func of(_ theme: AppTheme) -> ThemeColors {
        theme == .garden ? garden : classic
    }

    // MARK: Violet & Aqua
    static let classic = ThemeColors(
        eyes: Ramp(
            light: Color(rgb: 0xE6D9FF),    // lavender mist
            bright: Color(rgb: 0xBA99FF),
            accent: Color(rgb: 0x8C5CF7),   // violet
            deep: Color(rgb: 0x6B36E0),     // white text 6.5:1
            dark: Color(rgb: 0x2E1470)
        ),
        water: Ramp(
            light: Color(rgb: 0xE8FCFF),
            bright: Color(rgb: 0x5FE0FF),   // aqua
            accent: Color(rgb: 0x14B8FF),   // vivid sky
            deep: Color(rgb: 0x0490F5),     // clear blue
            dark: Color(rgb: 0x0A62D6)
        ),
        waterInk: Color(rgb: 0x06355E),     // 8:1 on the aqua fill
        alert: Color(rgb: 0xEB1F4D),
        page: Page(
            paper: Color(light: 0xFFFFFF, dark: 0x191919),
            ink: Color(light: 0x2F2E2B, dark: 0xE6E5E3),
            secondaryInk: Color(light: 0x73726E, dark: 0x9B9A97),   // 4.7:1 and 6.4:1 on paper
            hairline: Color(light: 0xEBEAE8, dark: 0x2D2D2C),
            wash: Color(light: 0xF2F1EE, dark: 0x262625)
        ),
        eyesBackdrop: Color(red: 0.03, green: 0.01, blue: 0.08).opacity(0.45),
        waterBackdrop: Color(red: 0.0, green: 0.07, blue: 0.15).opacity(0.30),
        eyesHex: "#8C5CF7", waterHex: "#14B8FF", eyesLightHex: "#E6D9FF", waterLightHex: "#E8FCFF",
        eyesBackdropHex: "#080214", waterBackdropHex: "#001226"
    )

    // MARK: Garden
    /// Leaf, rain and soil. Greens sit in the herb-bed range rather than lime; the water
    /// blue is a clear rain-butt blue; the ground is linen by day and a night garden's
    /// green-black after dark. Geranium red stays reserved for the dry-eye warning.
    static let garden = ThemeColors(
        eyes: Ramp(
            light: Color(rgb: 0xE2F0DC),    // new leaf
            bright: Color(rgb: 0x9DD196),
            accent: Color(rgb: 0x3E9A57),   // leaf green
            deep: Color(rgb: 0x2C7A43),     // white text 5.2:1
            dark: Color(rgb: 0x163D22)      // ivy
        ),
        water: Ramp(
            light: Color(rgb: 0xE3F3FA),
            bright: Color(rgb: 0x86D3EF),   // rain
            accent: Color(rgb: 0x2F9FD3),
            deep: Color(rgb: 0x1C7DB4),     // watering-can blue
            dark: Color(rgb: 0x0F4B6E)
        ),
        waterInk: Color(rgb: 0x0B3550),
        alert: Color(rgb: 0xD9452C),        // geranium
        page: Page(
            paper: Color(light: 0xFAF9F4, dark: 0x151A15),        // linen / night garden
            ink: Color(light: 0x24301F, dark: 0xE3E8DE),
            secondaryInk: Color(light: 0x66705F, dark: 0x9BA595),  // sage; 5.2:1 and 6.6:1 on paper
            hairline: Color(light: 0xE6E4D8, dark: 0x263025),
            wash: Color(light: 0xF0EEE3, dark: 0x1F261E)
        ),
        eyesBackdrop: Color(red: 0.02, green: 0.07, blue: 0.03).opacity(0.45),
        waterBackdrop: Color(red: 0.0, green: 0.08, blue: 0.11).opacity(0.30),
        eyesHex: "#3E9A57", waterHex: "#2F9FD3", eyesLightHex: "#E2F0DC", waterLightHex: "#E3F3FA",
        eyesBackdropHex: "#061209", waterBackdropHex: "#00141C"
    )
}

// MARK: - Palette
/// The current theme's colours, by job. Solid colours only; accents mark actions, selection
/// and state, never decoration.
enum Theme {
    /// The app sets this from Settings; the widget sets it from the shared file.
    static var current: AppTheme = .classic
    static var colors: ThemeColors { .of(current) }

    // Eyes — breaks, exercises, ambient nudges and the app's own chrome
    static var light: Color { colors.eyes.light }
    static var bright: Color { colors.eyes.bright }
    static var accent: Color { colors.eyes.accent }
    static var deep: Color { colors.eyes.deep }
    static var dark: Color { colors.eyes.dark }

    // Water
    enum Water {
        static var light: Color { Theme.colors.water.light }
        static var bright: Color { Theme.colors.water.bright }
        static var accent: Color { Theme.colors.water.accent }
        static var deep: Color { Theme.colors.water.deep }
        static var dark: Color { Theme.colors.water.dark }
        static var ink: Color { Theme.colors.waterInk }
    }

    /// Reserved red. Nothing in the app uses it now that the dry-eye picture is gone; kept so
    /// a warning, if one is ever needed, has a colour that means it.
    static var alert: Color { colors.alert }

    /// The eye colour for symbols and selection on paper: deep in light mode, the accent in
    /// dark mode, where deep violet falls under 3:1 on the dark page.
    static var onPage: Color { Color(light: colors.eyes.deep, dark: colors.eyes.accent) }

    /// The neutral ground of the app window, popover and widgets, in the Notion/TickTick
    /// manner: opaque paper, warm ink, hairlines. Colour stays with the habits.
    enum Page {
        static var paper: Color { Theme.colors.page.paper }
        static var ink: Color { Theme.colors.page.ink }
        static var secondaryInk: Color { Theme.colors.page.secondaryInk }
        static var hairline: Color { Theme.colors.page.hairline }
        static var wash: Color { Theme.colors.page.wash }
    }
}
