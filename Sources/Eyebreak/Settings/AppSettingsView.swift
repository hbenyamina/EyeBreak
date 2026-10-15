import SwiftUI

/// The app itself: how it looks and speaks, what the menu bar shows, whether it opens at
/// login. Reminder colours, sound, shortcuts, your data and the version wait under More options.
struct AppSettingsView: View {
    @ObservedObject var settings: AppSettings
    let shift: ShiftModel
    @ObservedObject var loginItemManager: LoginItemManager
    let resetHistory: () -> Void

    @State private var language = AppLanguage.current
    @State private var confirmingReset = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.1"
    }

    var body: some View {
        SettingsPage(pane: .app) {
            SettingsSection(title: "Theme", footer: .verbatim(settings.appTheme.detail)) {
                HStack(spacing: 14) {
                    ForEach(AppTheme.allCases) { theme in
                        AppThemeChoice(theme: theme, isSelected: settings.appTheme == theme) {
                            settings.appTheme = theme
                            // The End of Shift widget follows into the garden, and back, unless you chose its theme yourself
                            if theme == .garden && shift.themeID == ShiftTheme.defaultID {
                                shift.themeID = ShiftTheme.greenhouse.id
                            } else if theme == .classic && shift.themeID == ShiftTheme.greenhouse.id {
                                shift.themeID = ShiftTheme.defaultID
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
            }

            SettingsSection(title: "EyeBreak") {
                PickerRow(title: "Language", detail: language == AppLanguage.current ? nil : "EyeBreak restarts to switch.", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text(verbatim: $0.label).tag($0) }
                }
                .onChange(of: language) { _, choice in
                    guard choice != AppLanguage.current else { return }
                    choice.apply()
                    AppLanguage.relaunch()
                }
                PickerRow(
                    title: "Menu bar shows",
                    detail: "Beside the eye: the time to your next break, what's left of your shift, or both.",
                    selection: $settings.menuBarCountdown
                ) {
                    ForEach(MenuBarCountdown.allCases) { Text(verbatim: $0.label).tag($0) }
                }
                ToggleRow(
                    title: "Open at login",
                    isOn: Binding(
                        get: { loginItemManager.isLaunchAtLoginEnabled },
                        set: { _ in loginItemManager.toggleLaunchAtLogin() }
                    )
                )
            }

            MoreOptions {
                SettingsSection(title: "Behaviour") {
                    ToggleRow(title: "Sounds", subtitle: "A soft chime when a break starts and ends, and for water.", isOn: $settings.soundEffectsEnabled)
                    ToggleRow(title: "Start the timer when EyeBreak opens", isOn: $settings.autoStartTimer)
                }

                ForEach(ThemeSurface.allCases) { surface in
                    ThemeSection(surface: surface, settings: settings)
                }

                SettingsSection(title: "Keys") {
                    ValueRow(title: "Skip a break, or say not now to water", value: "esc")
                    ValueRow(title: "I drank, on a water reminder", value: "↩")
                    ValueRow(title: "Skip a break from any app", value: "⌥⇧⎋")
                }

                SettingsSection(title: "Your data", footer: "Everything EyeBreak records stays on your Mac. Nothing is sent anywhere.") {
                    ActionRow(title: "Reset history", detail: "Deletes your breaks, today's lines and the streak.", button: "Reset…", role: .destructive) {
                        confirmingReset = true
                    }
                }

                SettingsSection(title: "About") {
                    HStack(alignment: .top, spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EyeBreak \(version)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Page.ink)
                            Text("A quiet companion for the working day: short breaks to look away and blink, an hourly break on your feet, water, and a countdown to the end of your shift. Each number comes from published research.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Page.secondaryInk)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .alert("Reset your history?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { resetHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your breaks, today's lines and the streak will be deleted.")
        }
    }
}

// MARK: - Language
/// The app's own language, whatever the Mac's is. Stored as the app's `AppleLanguages`,
/// which macOS reads at launch, so a change needs a restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", arabic = "ar"

    var id: String { rawValue }

    /// Each language in its own words, so it can be found whichever is showing.
    var label: String {
        switch self {
        case .system: return String(localized: "Same as This Mac")
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }

    static var current: AppLanguage {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        guard let first = (domain["AppleLanguages"] as? [String])?.first else { return .system }
        return first.hasPrefix("ar") ? .arabic : .english
    }

    func apply() {
        let defaults = UserDefaults.standard
        switch self {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .english: defaults.set(["en"], forKey: "AppleLanguages")
        // Only the language: dates, digits and the calendar stay as the Mac has them
        case .arabic: defaults.set(["ar"], forKey: "AppleLanguages")
        }
        // macOS mirrors an app's windows for a right-to-left language only when the whole Mac
        // uses one; an app set to Arabic on its own has to ask
        for key in ["AppleTextDirection", "NSForceRightToLeftWritingDirection"] {
            if self == .arabic { defaults.set(true, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }

    /// Opens a fresh copy of the app and quits this one.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

// MARK: - App Theme
/// One look the app can wear, drawn in its own colours: its paper, a line for the eyes and
/// one for water, each catching once, the way the day's rhythm draws them.
private struct AppThemeChoice: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let colors = ThemeColors.of(theme)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 9) {
                    sampleLine(colors.eyes.accent, catchAt: 0.35)
                    sampleLine(colors.water.deep, catchAt: 0.62)
                    HStack(spacing: 6) {
                        Capsule().fill(colors.eyes.deep).frame(width: 34, height: 12)
                        Capsule().fill(colors.water.bright).frame(width: 22, height: 12)
                    }
                }
                .padding(12)
                .frame(width: 168, height: 92, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.page.paper))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? colors.eyes.deep : colors.page.hairline, lineWidth: isSelected ? 2 : 1)
                }

                Text(verbatim: theme.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.Page.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: theme.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A short rhythm line with one catch, as the day's lines draw it.
    private func sampleLine(_ color: Color, catchAt x: Double) -> some View {
        let window = DateInterval(start: Date(timeIntervalSinceReferenceDate: 0), duration: 8 * 3600)
        return RhythmLine(
            misses: [window.start.addingTimeInterval(window.duration * x)],
            window: window,
            now: window.end,
            color: color,
            lineWidth: 2,
            trackColor: .clear
        )
        .frame(height: 16)
    }
}

// MARK: - Reminder Colours
private struct ThemeSection: View {
    let surface: ThemeSurface
    @ObservedObject var settings: AppSettings
    @State private var randomPalette = Palette.random()

    private var type: Binding<ThemeType> {
        Binding(
            get: { settings.themeTypes[surface] ?? .standard },
            set: { settings.themeTypes[surface] = $0 }
        )
    }

    private var theme: Binding<ColorTheme> {
        Binding(
            get: { settings.customThemes[surface] ?? .standard(for: surface) },
            set: { settings.customThemes[surface] = $0 }
        )
    }

    private var previewPalette: Palette {
        switch type.wrappedValue {
        case .standard: return surface.defaultPalette
        case .random: return randomPalette
        case .custom: return Palette(custom: theme.wrappedValue)
        }
    }

    var body: some View {
        SettingsSection(title: .verbatim(surface.title), footer: .verbatim(type.wrappedValue.detail)) {
            SettingRow(title: "Colours") {
                Picker("Colours", selection: type) {
                    ForEach(ThemeType.allCases) { Text(verbatim: $0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            SettingRow(title: "Preview") {
                HStack(spacing: 10) {
                    if type.wrappedValue == .random {
                        Button("Shuffle") { randomPalette = .random() }
                            .controlSize(.small)
                    }
                    ThemePreview(surface: surface, palette: previewPalette)
                }
            }

            if type.wrappedValue == .custom {
                ColorRow(title: "Background", hex: theme.backgroundColorHex, opacity: theme.backgroundOpacity)
                ColorRow(title: "Text", hex: theme.textColorHex, opacity: theme.textOpacity)
                ColorRow(title: "Secondary text", hex: theme.secondaryTextColorHex, opacity: theme.secondaryTextOpacity)
                ColorRow(title: "Accent", hex: theme.accentColorHex, opacity: theme.accentOpacity)
                SettingRow(title: "Glass rim") {
                    Slider(value: theme.glassHighlightOpacity, in: 0...1)
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 170)
                }
                ActionRow(title: "Start over", button: "Reset to Theme") { theme.wrappedValue = .standard(for: surface) }
            }
        }
        .tint(surface.defaultPalette.deep)
    }
}

/// A miniature of the surface over the frost: the break screen's step, or the water toast.
private struct ThemePreview: View {
    let surface: ThemeSurface
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                CountdownRing(progress: 0.7, style: .compact)
                Image(systemName: surface == .breakOverlay ? "binoculars" : "drop.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(surface == .breakOverlay ? "Look across the room" : "Time for some water")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text ?? .white)
                Text("This is how it will look")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText ?? palette.light.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.surfaceTint))
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.1))
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.backdropTint)
            }
        )
        .environment(\.palette, palette)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview"))
    }
}

// MARK: - Colour Row
private struct ColorRow: View {
    let title: LocalizedStringKey
    @Binding var hex: String
    @Binding var opacity: Double

    var body: some View {
        SettingRow(title: title) {
            HStack(spacing: 10) {
                ColorPicker(title, selection: Binding(
                    get: { Color(hex: hex) },
                    set: { hex = NSColor($0).hexString }
                ), supportsOpacity: false)
                .labelsHidden()

                Slider(value: $opacity, in: 0...1)
                    .labelsHidden()
                    .frame(maxWidth: 160)
                    .accessibilityLabel(Text(title))

                Text(opacity.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }
}
