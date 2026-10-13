import SwiftUI

struct ScheduleSettingsView: View {
    @ObservedObject var settings: AppSettings

    private var calendar: Calendar { Calendar.current }

    /// Weekday numbers (1 = Sunday) in the user's locale order.
    private var orderedWeekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    /// nil when the hours don't match a preset.
    private var preset: Binding<SchedulePreset?> {
        Binding(
            get: {
                SchedulePreset.allCases.first { $0.hours.start == settings.workHoursStart && $0.hours.end == settings.workHoursEnd }
            },
            set: { if let preset = $0 { settings.apply(preset) } }
        )
    }

    var body: some View {
        SettingsPage(title: "Schedule") {
            Section {
                ToggleRow(title: "Smart Schedule", isOn: $settings.smartScheduleEnabled)
                if settings.smartScheduleEnabled {
                    let active = PresenceMonitor.isWithinSchedule(settings: settings)
                    LabeledContent("Right now") {
                        Text(active ? "Breaks are on" : "Paused, outside your work hours")
                            .foregroundStyle(active ? Theme.accent : Color.secondary)
                    }
                }
            } footer: {
                Text("Pauses breaks and reminders outside your work hours.")
            }

            if settings.smartScheduleEnabled {
                Section("Work Hours") {
                    Picker("Preset", selection: preset) {
                        ForEach(SchedulePreset.allCases) { Text($0.label).tag(Optional($0)) }
                        Text("Custom").tag(SchedulePreset?.none)
                    }
                    hourPicker("From", selection: $settings.workHoursStart)
                    hourPicker("To", selection: $settings.workHoursEnd)
                }

                Section {
                    LabeledContent("Days") {
                        HStack(spacing: 4) {
                            ForEach(orderedWeekdays, id: \.self) { day in
                                Toggle(isOn: Binding(
                                    get: { settings.activeDays.contains(day) },
                                    set: { isOn in
                                        if isOn { settings.activeDays.insert(day) } else { settings.activeDays.remove(day) }
                                    }
                                )) {
                                    Text(calendar.veryShortWeekdaySymbols[day - 1])
                                        .frame(minWidth: 16)
                                }
                                .toggleStyle(.button)
                                .help(calendar.weekdaySymbols[day - 1])
                                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                            }
                        }
                    }
                    ToggleRow(title: "Pause on weekends", subtitle: "Uses your region's weekend days", isOn: $settings.pauseOnWeekends)
                } header: {
                    Text("Active Days")
                }
            }
        }
    }

    private func hourPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(AppSettings.hourLabel(hour)).tag(hour)
            }
        }
    }
}
