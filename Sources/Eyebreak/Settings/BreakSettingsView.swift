import SwiftUI

struct BreakSettingsView: View {
    @ObservedObject var settings: AppSettings
    let previewBreak: () -> Void

    /// Choosing "Custom" keeps the current values; the sliders below do the editing.
    private var preset: Binding<TimingPreset> {
        Binding(get: { settings.timingPreset }, set: { settings.apply($0) })
    }

    var body: some View {
        SettingsPage(title: "Breaks") {
            Section {
                Picker("Preset", selection: preset) {
                    ForEach(TimingPreset.allCases) { Text($0.rawValue).tag($0) }
                }
                SliderRow(title: "Work interval", value: $settings.workIntervalMinutes, range: 1...90, format: SettingsFormat.minutes)
                SliderRow(title: "Break length", value: $settings.breakDurationSeconds, range: 10...600, step: 5, format: SettingsFormat.seconds)
                SliderRow(title: "Warning before a break", value: $settings.preBreakWarningSeconds, range: 0...60) {
                    $0 == 0 ? "Off" : SettingsFormat.seconds($0)
                }
            } header: {
                Text("Timing")
            } footer: {
                Text(settings.timingPreset.detail)
            }

            Section {
                Picker("Style", selection: $settings.breakStyle) {
                    ForEach(BreakStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("See what a break looks like") {
                    Button("Preview", action: previewBreak)
                }
            } header: {
                Text("Break Style")
            } footer: {
                Text(settings.breakStyle.detail)
            }

            if settings.breakStyle == .eyeExercise {
                Section {
                    SliderRow(title: "Exercise length", value: $settings.eyeExerciseDurationSeconds, range: 10...120, step: 5, format: SettingsFormat.seconds)
                    SliderRow(title: "Hold each position", value: $settings.exerciseIntervalSeconds, range: 1...10, format: SettingsFormat.seconds)
                } header: {
                    Text("Eye Exercise")
                }
            }

            Section {
                HStack(spacing: 14) {
                    Stepper(
                        settings.skipsBeforeDryEyeNudge == 1
                            ? "Show after 1 skipped break"
                            : "Show after \(settings.skipsBeforeDryEyeNudge) skipped breaks in a row",
                        value: $settings.skipsBeforeDryEyeNudge,
                        in: 1...10
                    )
                    DryEyeView()
                        .frame(width: 64)
                }
            } header: {
                Text("Dry-Eye Warning")
            } footer: {
                Text("Shows what skipped breaks do to your eyes, only when you keep ignoring them. Resets when you finish a break.")
            }
        }
    }
}
