import SwiftUI
import AppKit

// MARK: - Surfaces & Types
enum ThemeSurface: String, CaseIterable, Identifiable {
    case ambientReminder
    case breakOverlay
    case waterReminder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ambientReminder: return "Ambient Reminder Theme"
        case .breakOverlay: return "Break Overlay Theme"
        case .waterReminder: return "Water Reminder Theme"
        }
    }

    var icon: String {
        switch self {
        case .ambientReminder: return "sparkles"
        case .breakOverlay: return "eye.fill"
        case .waterReminder: return "drop.fill"
        }
    }

    /// Water is blue; everything about the eyes is violet.
    var defaultPalette: Palette { self == .waterReminder ? .water : .eyes }

    // 2.2.0 key names
    var typeKey: String { rawValue + "ThemeType" }
    var customThemeKey: String { rawValue + "CustomTheme" }
}

enum ThemeType: String, CaseIterable, Identifiable {
    case standard = "Default"
    case random = "Random Color"
    case custom = "Custom"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .standard: return "EyeBreak's own colours: violet for breaks, aqua for water."
        case .random: return "A different colour each time it appears."
        case .custom: return "Pick your own background, text and accent colours."
        }
    }
}

// MARK: - Custom Theme
struct ColorTheme: Codable, Equatable {
    var backgroundColorHex: String
    var backgroundOpacity: Double
    var textColorHex: String
    var textOpacity: Double
    var secondaryTextColorHex: String
    var secondaryTextOpacity: Double
    var accentColorHex: String
    var accentOpacity: Double
    var glassHighlightOpacity: Double

    /// Starting point for a custom theme: the surface's default colours.
    static func standard(for surface: ThemeSurface) -> ColorTheme {
        let water = surface == .waterReminder
        return ColorTheme(
            backgroundColorHex: water ? "#001226" : "#080214",
            backgroundOpacity: water ? 0.30 : 0.45,
            textColorHex: "#FFFFFF",
            textOpacity: 1,
            secondaryTextColorHex: water ? "#E8FCFF" : "#E6D9FF",
            secondaryTextOpacity: 0.75,
            accentColorHex: water ? "#14B8FF" : "#8C5CF7",
            accentOpacity: 1,
            glassHighlightOpacity: 0.35
        )
    }
}

// MARK: - Palette
/// The resolved colours a themed surface draws with.
struct Palette {
    var light: Color
    var bright: Color
    var accent: Color
    var deep: Color
    var dark: Color
    /// Laid over the full-screen frost (break overlay, blur-style water reminder).
    var backdropTint: Color
    /// Tints glass cards.
    var surfaceTint: Color
    /// nil = adaptive system colours (light/dark).
    var text: Color?
    var secondaryText: Color?
    /// Extra hairline rim on glass cards; nil keeps the system glass edge.
    var highlightOpacity: Double?
    /// Solid fill for primary buttons and selected states, and the text drawn on it.
    var fill: Color
    var onFill: Color

    /// Violet: breaks, eye exercises, ambient reminders.
    static let eyes = Palette(
        light: Theme.light,
        bright: Theme.bright,
        accent: Theme.accent,
        deep: Theme.deep,
        dark: Theme.dark,
        backdropTint: Color(red: 0.03, green: 0.01, blue: 0.08).opacity(0.45),
        surfaceTint: Theme.accent.opacity(0.08),
        text: nil,
        secondaryText: nil,
        highlightOpacity: nil,
        fill: Theme.deep,
        onFill: .white
    )

    /// Clear aqua-blue: water reminders. A lighter backdrop and aqua-tinted glass with a
    /// clean rim, like water in a clear cup; buttons are bright aqua with dark ink.
    static let water = Palette(
        light: Theme.Water.light,
        bright: Theme.Water.bright,
        accent: Theme.Water.accent,
        deep: Theme.Water.deep,
        dark: Theme.Water.dark,
        backdropTint: Color(red: 0.0, green: 0.07, blue: 0.15).opacity(0.30),
        surfaceTint: Theme.Water.accent.opacity(0.14),
        text: nil,
        secondaryText: nil,
        highlightOpacity: 0.35,
        fill: Theme.Water.bright,
        onFill: Theme.Water.ink
    )

    var textStyle: AnyShapeStyle { text.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary) }
    var secondaryTextStyle: AnyShapeStyle { secondaryText.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary) }

    /// Derives the five accent shades from a single colour, mirroring how the built-in ramps are shaped.
    init(accent accentColor: NSColor, opacity: Double = 1, backdropTint: Color = .black.opacity(0.42), text: Color? = nil, secondaryText: Color? = nil, highlightOpacity: Double? = nil) {
        let c = accentColor.usingColorSpace(.sRGB) ?? accentColor
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        func shade(_ sat: CGFloat, _ bright: CGFloat) -> Color {
            Color(hue: Double(h), saturation: Double(min(max(sat, 0), 1)), brightness: Double(min(max(bright, 0), 1))).opacity(opacity)
        }
        light = shade(s * 0.3, 1)
        bright = shade(s * 0.55, 1)
        accent = shade(s, b)
        deep = shade(s * 1.1, b * 0.9)
        dark = shade(s, b * 0.52)
        self.backdropTint = backdropTint
        surfaceTint = accent.opacity(0.08)
        self.text = text
        self.secondaryText = secondaryText
        self.highlightOpacity = highlightOpacity
        fill = deep
        onFill = .white
    }

    private init(light: Color, bright: Color, accent: Color, deep: Color, dark: Color, backdropTint: Color, surfaceTint: Color, text: Color?, secondaryText: Color?, highlightOpacity: Double?, fill: Color, onFill: Color) {
        self.fill = fill
        self.onFill = onFill
        self.light = light
        self.bright = bright
        self.accent = accent
        self.deep = deep
        self.dark = dark
        self.backdropTint = backdropTint
        self.surfaceTint = surfaceTint
        self.text = text
        self.secondaryText = secondaryText
        self.highlightOpacity = highlightOpacity
    }

    static func random() -> Palette {
        Palette(accent: NSColor(hue: .random(in: 0...1), saturation: .random(in: 0.6...0.85), brightness: 1, alpha: 1))
    }

    init(custom theme: ColorTheme) {
        let background = Color(hex: theme.backgroundColorHex)
        self.init(
            accent: NSColor(hex: theme.accentColorHex),
            opacity: theme.accentOpacity,
            backdropTint: background.opacity(theme.backgroundOpacity),
            text: Color(hex: theme.textColorHex).opacity(theme.textOpacity),
            secondaryText: Color(hex: theme.secondaryTextColorHex).opacity(theme.secondaryTextOpacity),
            highlightOpacity: theme.glassHighlightOpacity
        )
        surfaceTint = background.opacity(theme.backgroundOpacity * 0.5)
    }

    /// Resolves the palette a surface should use right now. Random themes re-roll on every call,
    /// so call this once per appearance.
    static func current(for surface: ThemeSurface, settings: AppSettings = .shared) -> Palette {
        switch settings.themeTypes[surface] ?? .standard {
        case .standard: return surface.defaultPalette
        case .random: return .random()
        case .custom: return Palette(custom: settings.customThemes[surface] ?? .standard(for: surface))
        }
    }
}

// MARK: - Environment
private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.eyes
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Hex Colours
extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))).scanHexInt64(&value)
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

// MARK: - Themed Glass
extension View {
    /// `glassSurface` plus the palette's tint and optional custom highlight rim.
    func themedGlass<S: InsettableShape>(in shape: S, palette: Palette, frosted: Bool = false) -> some View {
        glassSurface(in: shape, tint: palette.surfaceTint, frosted: frosted)
            .overlay {
                if let highlight = palette.highlightOpacity {
                    shape.strokeBorder(Color.white.opacity(highlight), lineWidth: 0.75)
                }
            }
    }
}
