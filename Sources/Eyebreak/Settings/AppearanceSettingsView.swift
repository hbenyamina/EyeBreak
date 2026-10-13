import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(title: "Appearance") {
            ForEach(ThemeSurface.allCases) { surface in
                ThemeSection(surface: surface, settings: settings)
            }
        }
    }
}

// MARK: - Theme Section
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
        Section {
            Picker("Colours", selection: type) {
                ForEach(ThemeType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            LabeledContent("Preview") {
                HStack(spacing: 10) {
                    if type.wrappedValue == .random {
                        Button("Shuffle") { randomPalette = .random() }
                    }
                    ThemePreview(surface: surface, palette: previewPalette)
                }
            }

            if type.wrappedValue == .custom {
                ColorRow(title: "Background", hex: theme.backgroundColorHex, opacity: theme.backgroundOpacity)
                ColorRow(title: "Text", hex: theme.textColorHex, opacity: theme.textOpacity)
                ColorRow(title: "Secondary text", hex: theme.secondaryTextColorHex, opacity: theme.secondaryTextOpacity)
                ColorRow(title: "Accent", hex: theme.accentColorHex, opacity: theme.accentOpacity)
                LabeledContent("Glass rim") {
                    Slider(value: theme.glassHighlightOpacity, in: 0...1)
                        .labelsHidden()
                        .frame(maxWidth: 240)
                }
                LabeledContent("") {
                    Button("Reset to Default") { theme.wrappedValue = .standard(for: surface) }
                }
            }
        } header: {
            Text(surface.title)
        } footer: {
            Text(type.wrappedValue.detail)
        }
        .tint(surface.defaultPalette.deep)
    }
}

// MARK: - Preview
/// A miniature of the surface on a dark swatch, the way it appears over the frost.
private struct ThemePreview: View {
    let surface: ThemeSurface
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                CountdownRing(progress: 0.7, style: .compact)
                Image(systemName: surface.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(previewTitle)
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
        .accessibilityLabel("Theme preview")
    }

    private var previewTitle: String {
        switch surface {
        case .ambientReminder: return "Look to the left"
        case .breakOverlay: return "Time for a break"
        case .waterReminder: return "Drink up"
        }
    }
}

// MARK: - Colour Row
private struct ColorRow: View {
    let title: String
    @Binding var hex: String
    @Binding var opacity: Double

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                ColorPicker(title, selection: Binding(
                    get: { Color(hex: hex) },
                    set: { hex = NSColor($0).hexString }
                ), supportsOpacity: false)
                .labelsHidden()

                Slider(value: $opacity, in: 0...1)
                    .labelsHidden()
                    .frame(maxWidth: 160)
                    .accessibilityLabel("\(title) opacity")

                Text("\(Int(opacity * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}
