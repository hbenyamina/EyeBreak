import SwiftUI

/// The workday: today's start, the hours and days, and whether everything pauses outside
/// them. The End of Shift widget, the menu bar and the Smart Schedule pause all read these.
struct WorkdaySettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shift: ShiftModel
    @ObservedObject var prompt: UnlockPrompt

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        SettingsPage(pane: .workday) {
            today
            hours
            MoreOptions {
                zone
                lateStarts
                WidgetThemeSection(shift: shift)
            }
        }
    }

    // MARK: - Today
    private var today: some View {
        let status = shift.status
        return SettingsSection(title: "Today") {
            SettingRow(title: .verbatim(ShiftText.headline(for: status)), detail: .verbatim(shift.todayText)) {
                Text(verbatim: ShiftText.long(until: status?.target, from: shift.now))
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(shift.theme.heroAccent)
            }
            if shift.adjustedWindowToday != nil {
                ActionRow(title: "Started from now today", button: "Undo Late Start") { shift.clearAdjustedStart() }
            } else if shift.scheduledWindowToday != nil {
                ActionRow(title: "Running late or early?", detail: "Start today's shift from this moment; the end moves with it.", button: "Start from Now") {
                    shift.startShift(at: shift.now)
                }
            }
        }
    }

    // MARK: - Hours
    private var hours: some View {
        SettingsSection(title: "Hours", footer: .verbatim(footnote)) {
            SettingRow(title: "Starts") {
                DatePicker("Starts", selection: time(\.startHour, \.startMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            SettingRow(title: "Ends", detail: "Earlier than the start means a night shift, ending the next morning.") {
                DatePicker("Ends", selection: time(\.endHour, \.endMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            SettingRow(title: "Days") { weekdays }
            ToggleRow(
                title: "Pause everything outside these hours",
                subtitle: settings.smartScheduleEnabled
                    ? (shift.isOnShift(at: shift.now) ? "On shift now, so breaks and reminders are on." : "Off shift now, so breaks and reminders are paused.")
                    : "Evenings, days off and the time before a late start stay quiet.",
                isOn: $settings.smartScheduleEnabled
            )
        }
    }

    // MARK: - Time zone
    private var zone: some View {
        SettingsSection(title: "Presets and time zone") {
            PickerRow(title: "Preset", selection: preset) {
                ForEach(SchedulePreset.allCases) { Text(verbatim: $0.label).tag(Optional($0)) }
                Text("Custom").tag(SchedulePreset?.none)
            }
            PickerRow(title: "Time zone", selection: regionChoice) {
                Text("Same as this Mac").tag(String?.none)
                Divider()
                ForEach(TimeZoneCatalog.regions, id: \.self) { region in
                    Text(verbatim: region).tag(String?.some(region))
                }
            }
            if let region = regionChoice.wrappedValue {
                PickerRow(title: "City", selection: cityChoice) {
                    ForEach(TimeZoneCatalog.cities(in: region), id: \.identifier) { city in
                        Text(verbatim: city.name).tag(city.identifier)
                    }
                }
            }
        }
    }

    // MARK: - Late starts
    private var lateStarts: some View {
        SettingsSection(
            title: "Starting late",
            footer: "The first unlock while a shift is due asks whether to start it from that moment. Yes keeps the shift's length, so the end moves too. It's for that day only."
        ) {
            ToggleRow(
                title: "Ask when this Mac is unlocked",
                subtitle: prompt.notificationsDenied
                    ? "Notifications are off for EyeBreak, so the question appears as a small panel at the top right."
                    : nil,
                isOn: $settings.askOnUnlock
            )
        }
    }

    // MARK: - Bindings
    private var preset: Binding<SchedulePreset?> {
        Binding(get: { shift.preset }, set: { if let preset = $0 { shift.apply(preset) } })
    }

    /// The day chips, starting on whichever day the user's calendar starts on. A working day
    /// is a solid chip in the theme's colour; a day off is an outline.
    private var weekdays: some View {
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack(spacing: 5) {
            ForEach(order, id: \.self) { day in
                DayChip(
                    letter: calendar.veryShortWeekdaySymbols[day - 1],
                    name: calendar.weekdaySymbols[day - 1],
                    isOn: shift.schedule.weekdays.contains(day),
                    isLast: shift.schedule.weekdays == [day]
                ) {
                    if shift.schedule.weekdays.contains(day) {
                        // At least one day stays on, or there's nothing to count down to
                        guard shift.schedule.weekdays.count > 1 else { return }
                        shift.schedule.weekdays.remove(day)
                    } else {
                        shift.schedule.weekdays.insert(day)
                    }
                }
            }
        }
    }

    private var regionChoice: Binding<String?> {
        Binding(
            get: { shift.schedule.timeZoneIdentifier.map(TimeZoneCatalog.region(of:)) },
            set: { region in
                guard let region else {
                    shift.schedule.timeZoneIdentifier = nil
                    return
                }
                // Keep the city if it already belongs to the newly picked region.
                if let current = shift.schedule.timeZoneIdentifier, TimeZoneCatalog.region(of: current) == region {
                    return
                }
                shift.schedule.timeZoneIdentifier = TimeZoneCatalog.cities(in: region).first?.identifier
            }
        )
    }

    private var cityChoice: Binding<String> {
        Binding(
            get: { shift.schedule.timeZoneIdentifier ?? TimeZone.current.identifier },
            set: { shift.schedule.timeZoneIdentifier = $0 }
        )
    }

    private func time(_ hour: WritableKeyPath<ShiftSchedule, Int>,
                      _ minute: WritableKeyPath<ShiftSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.year = 2001
                components.month = 1
                components.day = 1
                components.hour = shift.schedule[keyPath: hour]
                components.minute = shift.schedule[keyPath: minute]
                return calendar.date(from: components) ?? Date()
            },
            set: { newValue in
                let parts = calendar.dateComponents([.hour, .minute], from: newValue)
                shift.schedule[keyPath: hour] = parts.hour ?? 0
                shift.schedule[keyPath: minute] = parts.minute ?? 0
            }
        )
    }

    /// "8h shift · Sun–Thu. Follows this Mac's time zone (GMT+3)."
    private var footnote: String {
        let schedule = shift.schedule
        let overnight = schedule.endMinutes <= schedule.startMinutes
        var text = overnight
            ? String(localized: "\(schedule.durationText) overnight, ending the next morning")
            : String(localized: "\(schedule.durationText) shift")
        text += " · \(schedule.daysText())"

        if let zone = schedule.timeZoneText {
            text += ". " + String(localized: "Read in \(zone) (\(TimeZoneCatalog.offsetText(for: schedule.timeZone)))")
            if let end = shift.status?.window.end, schedule.differsFromSystemClock() {
                text += String(localized: ": that's \(schedule.systemClockText(for: end)) on this Mac")
            }
            text += "."
        } else {
            text += ". " + String(localized: "Follows this Mac's time zone (\(TimeZoneCatalog.offsetText(for: .current))).")
        }
        return text
    }
}

/// One day of the week: solid when you work it, an outline when you don't.
private struct DayChip: View {
    let letter: String
    let name: String
    let isOn: Bool
    /// The only working day left can't be switched off.
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: letter)
                .font(.system(size: 12, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Palette.eyes.onFill : Theme.Page.secondaryInk)
                .frame(width: 28, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Theme.deep : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : Theme.Page.hairline, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: isLast ? String(localized: "\(name): your only working day") : name))
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(isOn ? "Working day" : "Day off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Widget Theme
/// The End of Shift widget: how to add it, and its colours. Its three solid surfaces stand
/// for the shift's states, so the preview shows all three.
struct WidgetThemeSection: View {
    @ObservedObject var shift: ShiftModel

    var body: some View {
        SettingsSection(
            title: "End of Shift widget",
            footer: "Counts down to the end of your shift, then to the next one, even with EyeBreak quit. To add it, right-click the desktop, choose Edit Widgets and search for EyeBreak. With tinted or clear widgets, macOS supplies the colour."
        ) {
            PickerRow(title: "Colours", selection: $shift.themeID) {
                ForEach(ShiftTheme.Family.allCases) { family in
                    Section(family.label) {
                        ForEach(ShiftTheme.all(in: family)) { Text(verbatim: $0.name).tag($0.id) }
                    }
                }
            }
            SettingRow(title: "Preview", detail: "On shift, before it, and off the clock.") {
                HStack(spacing: 8) {
                    WidgetSurfacePreview(surface: shift.theme.working, symbol: "hourglass", caption: "On shift", showsProgress: true)
                    WidgetSurfacePreview(surface: shift.theme.ahead, symbol: "sunrise.fill", caption: "Before", showsProgress: false)
                    WidgetSurfacePreview(surface: shift.theme.off, symbol: "moon.zzz.fill", caption: "Off", showsProgress: false)
                }
            }
        }
    }
}

/// A miniature widget tile in one state's surface and inks.
private struct WidgetSurfacePreview: View {
    let surface: ShiftTheme.Surface
    let symbol: String
    let caption: LocalizedStringKey
    /// Only a running shift has a progress bar, as on the widget.
    let showsProgress: Bool

    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(surface.inkSoft)
                Text(verbatim: "3:24")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(surface.ink)
                Capsule()
                    .fill(surface.track)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(surface.ink).frame(width: 22, height: 3)
                    }
                    .opacity(showsProgress ? 1 : 0)
            }
            .padding(8)
            .frame(width: 64, height: 56, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(surface.color))

            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(caption))
    }
}
