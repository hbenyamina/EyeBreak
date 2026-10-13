import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemManager: LoginItemManager

    var body: some View {
        SettingsPage(title: "General") {
            if !settings.hasLaunchedBefore {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start your healthy eye habit")
                                .font(.headline)
                            Text("Every 20 minutes, look at something 20 feet away for 20 seconds. EyeBreak handles the reminding.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Got it") { settings.hasLaunchedBefore = true }
                            .buttonStyle(AccentButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Startup") {
                ToggleRow(
                    title: "Launch at login",
                    isOn: Binding(
                        get: { loginItemManager.isLaunchAtLoginEnabled },
                        set: { _ in loginItemManager.toggleLaunchAtLogin() }
                    )
                )
                ToggleRow(title: "Start the timer when EyeBreak opens", isOn: $settings.autoStartTimer)
            }

            Section("Menu Bar") {
                ToggleRow(title: "Show countdown next to the icon", subtitle: "Time until your next break, or what's left of the current one", isOn: $settings.showMenuBarCountdown)
            }

            Section("Sound") {
                ToggleRow(title: "Sound effects", subtitle: "Soft chimes when breaks start and end, and for reminders", isOn: $settings.soundEffectsEnabled)
            }

            Section {
                ToggleRow(title: "Pause when I'm away", isOn: $settings.idleDetectionEnabled)
                if settings.idleDetectionEnabled {
                    SliderRow(title: "Away after", value: $settings.idleThresholdMinutes, range: 1...30, format: SettingsFormat.minutes)
                }
            } header: {
                Text("Away Detection")
            } footer: {
                Text("When you step away or lock your screen, EyeBreak pauses. The timer starts fresh when you're back, since you already rested.")
            }

            Section("Daily Goal") {
                Stepper("\(settings.dailyBreakGoal) breaks a day", value: $settings.dailyBreakGoal, in: 1...40)
            }

            Section("Shortcuts") {
                LabeledContent("Skip a break or snooze a reminder", value: "esc")
                LabeledContent("Skip a break from any app", value: "⌥⇧⎋")
            }
        }
    }
}
