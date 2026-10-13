import SwiftUI

struct RemindersSettingsView: View {
    @ObservedObject var settings: AppSettings
    let showWaterNow: () -> Void
    let showAmbientNow: () -> Void

    private let iconColumns = Array(repeating: GridItem(.fixed(36), spacing: 6), count: 6)

    var body: some View {
        SettingsPage(title: "Reminders") {
            waterSection
            ambientSection
        }
    }

    // MARK: - Water
    private var waterSection: some View {
        Section {
            ToggleRow(title: "Water reminders", isOn: $settings.waterReminderEnabled)

            if settings.waterReminderEnabled {
                SliderRow(title: "Every", value: $settings.waterReminderInterval, range: 10...180, step: 5, format: SettingsFormat.minutes)

                Picker("Style", selection: $settings.waterReminderStyle) {
                    ForEach(WaterReminderStyle.allCases) { Text($0.rawValue).tag($0) }
                }

                ToggleRow(title: "Custom icon and message", isOn: $settings.useCustomWaterReminder)

                if settings.useCustomWaterReminder {
                    LabeledContent("Icon") {
                        LazyVGrid(columns: iconColumns, alignment: .trailing, spacing: 6) {
                            ForEach(WaterReminderManager.iconOptions, id: \.symbol) { option in
                                IconOptionButton(
                                    symbol: option.symbol,
                                    name: option.name,
                                    isSelected: settings.customWaterReminderIcon == option.symbol
                                ) {
                                    settings.customWaterReminderIcon = option.symbol
                                }
                            }
                        }
                        .frame(maxWidth: 252)
                    }
                    TextField("Message", text: $settings.customWaterReminderMessage, prompt: Text("Time for a glass of water!"))
                }

                LabeledContent("Try it") {
                    Button("Show Water Reminder", action: showWaterNow)
                }
            }
        } header: {
            Text("Water")
        } footer: {
            if settings.waterReminderEnabled {
                Text(settings.waterReminderStyle.detail)
            }
        }
        // Water reads aqua: switches, sliders and the selected icon
        .environment(\.palette, .water)
        .tint(Theme.Water.deep)
    }

    // MARK: - Ambient
    private var ambientSection: some View {
        Section {
            ToggleRow(title: "Ambient reminders", isOn: $settings.ambientRemindersEnabled)

            if settings.ambientRemindersEnabled {
                SliderRow(title: "Every", value: $settings.ambientReminderIntervalMinutes, range: 1...60, format: SettingsFormat.minutes)
                SliderRow(title: "Stay on screen for", value: $settings.ambientReminderDurationSeconds, range: 2...30, format: SettingsFormat.seconds)

                ToggleRow(title: "Use my own reminder", isOn: $settings.useCustomReminder)

                if settings.useCustomReminder {
                    HStack(spacing: 8) {
                        TextField("Emoji", text: Binding(
                            get: { settings.customReminderEmoji },
                            set: { settings.customReminderEmoji = String($0.prefix(2)) }
                        ))
                        .labelsHidden()
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Reminder emoji")

                        TextField("Message", text: $settings.customReminderMessage, prompt: Text("Blink and look away"))
                            .labelsHidden()
                    }
                }

                LabeledContent("Try it") {
                    Button("Show Ambient Reminder", action: showAmbientNow)
                }
            }
        } header: {
            Text("Ambient")
        } footer: {
            Text("Small nudges to blink or look away. They never take focus and fade on their own.")
        }
    }
}

// MARK: - Icon Option
private struct IconOptionButton: View {
    let symbol: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? palette.onFill : Color.secondary)
                .frame(width: 36, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? palette.fill : Color.primary.opacity(0.05))
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
