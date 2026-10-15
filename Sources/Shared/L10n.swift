import Foundation

/// Where the shared code's words come from. The app runs in its own language (Settings →
/// App → Language), but macOS gives a widget extension the Mac's; so the app writes its
/// language into the shared file and the widget follows it here.
enum L10n {
    nonisolated(unsafe) private(set) static var bundle: Bundle = .main
    nonisolated(unsafe) private(set) static var language: String?

    /// The app's language as macOS chose it: "ar" or "en".
    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }

    /// Switches to `language`'s strings, when this bundle has them.
    static func follow(language code: String?) {
        guard let code, let path = Bundle.main.path(forResource: code, ofType: "lproj"), let strings = Bundle(path: path) else {
            bundle = .main
            language = nil
            return
        }
        bundle = strings
        language = code
    }

    /// Arabic reads right to left.
    static var isRightToLeft: Bool {
        Locale.Language(identifier: language ?? appLanguage).characterDirection == .rightToLeft
    }

    /// The locale for numbers and dates in the chosen language, keeping the Mac's region.
    static var locale: Locale {
        guard let language else { return .current }
        var components = Locale.Components(locale: .current)
        components.languageComponents = Locale.Language.Components(identifier: language)
        return Locale(components: components)
    }
}

extension String {
    /// Localized from `L10n.bundle`, so the widget speaks the app's language.
    init(shared value: String.LocalizationValue) {
        self.init(localized: value, bundle: L10n.bundle)
    }

    /// Western digits in the locale's own (Arabic-Indic where the locale uses them), for
    /// times built with `String(format:)`, so they match the dates beside them.
    var localizedDigits: String {
        let locale = L10n.locale
        guard locale.numberingSystem.identifier != "latn" else { return self }
        let formatter = NumberFormatter()
        formatter.locale = locale
        let digits = (0...9).map { formatter.string(from: NSNumber(value: $0)) ?? "\($0)" }
        return String(self.flatMap { character -> String in
            guard character.isASCII, let value = character.wholeNumberValue else { return String(character) }
            return digits[value]
        })
    }
}
