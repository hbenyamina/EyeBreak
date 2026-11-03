import Charts
import Combine
import SwiftUI

/// Breaks: how you're keeping up, then the four things you'd come to change (the rhythm,
/// what a break looks like, waiting for a pause, holding for calls). Everything else,
/// history included, is under More options.
struct BreakSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsStore
    @ObservedObject var activity: ActivityModel
    @ObservedObject var shift: ShiftModel
    @ObservedObject var prompt: UnlockPrompt
    let previewBreak: () -> Void
    let showBlinkNow: () -> Void

    @State private var now = Date()
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// Choosing "Custom" keeps the current values; More options does the editing.
    private var preset: Binding<TimingPreset> {
        Binding(get: { settings.timingPreset }, set: { settings.apply($0) })
    }

    var body: some View {
        SettingsPage(pane: .breaks) {
            if !settings.hasLaunchedBefore {
                Callout(
                    icon: "eye",
                    title: "How EyeBreak works",
                    message: "Every 20 minutes, 30 seconds to look across the room and blink. Every hour, 5 minutes on your feet. Breaks wait for a pause in your typing and hold during calls. Start by setting your working hours under Workday."
                ) {
                    Button("Got It") { settings.hasLaunchedBefore = true }
                        .buttonStyle(AccentButtonStyle())
                }
            }

            SettingsSection(title: "Your rhythm", footer: "Straight while you take your breaks; it dips where you skip one.") {
                HabitRhythm(habit: .eyes, activity: activity, now: now,
                            value: String(localized: "\(activity.log.count(.breakTaken, on: now)) of \(activity.breakGoal)"))
            }

            SettingsSection(title: "Breaks") {
                PickerRow(title: "Rhythm", detail: .verbatim(settings.timingPreset.detail), selection: preset) {
                    ForEach(TimingPreset.allCases) { Text(verbatim: $0.title).tag($0) }
                }
                PickerRow(title: "Break screen", detail: .verbatim(styleDetail), selection: $settings.breakStyle) {
                    ForEach(BreakStyle.choices) { Text(verbatim: $0.label).tag($0) }
                }
                ToggleRow(title: "Wait for a pause in my typing",
                          subtitle: "Up to 2 minutes, so a break doesn't land mid-sentence.",
                          isOn: $settings.waitForPause)
                ToggleRow(title: "Hold breaks during calls",
                          subtitle: "While a camera or the microphone is on. EyeBreak only checks whether they're on; it never sees or hears anything.",
                          isOn: $settings.holdDuringCalls)
            }

            MoreOptions {
                timing
                goal
                blinks
                away
                history
                SettingsSection(title: "Try it") {
                    ActionRow(title: "See what a break looks like", button: "Preview", action: previewBreak)
                }
            }
        }
        .onReceive(minute) { now = $0 }
    }

    private var styleDetail: String {
        if settings.breakStyle == .notificationOnly && prompt.notificationsDenied {
            return String(localized: "Notifications are off for EyeBreak, so this style shows nothing. Turn them on in System Settings, or pick another.")
        }
        return settings.breakStyle.detail
    }

    // MARK: - Timing
    private var timing: some View {
        SettingsSection(title: "Timing", footer: "5 More Minutes holds a break back twice at most, and never counts as skipped.") {
            SliderRow(title: "Work between breaks", value: $settings.workIntervalMinutes, range: 5...90, step: 5, format: SettingsFormat.minutes)
            SliderRow(title: "Break length", value: $settings.breakDurationSeconds, range: 10...120, step: 5, format: SettingsFormat.seconds)
            PickerRow(title: "Long break", detail: "Stand up, refill your water, look out of a window.", selection: $settings.longBreakEvery) {
                Text("Never").tag(0)
                ForEach(2...8, id: \.self) { Text(verbatim: Self.everyNth($0)).tag($0) }
            }
            if settings.longBreakEvery > 0 {
                SliderRow(title: "Long break length", value: $settings.longBreakMinutes, range: 2...30, format: SettingsFormat.minutes)
            }
            PickerRow(title: "Heads-up before a break",
                      detail: settings.preBreakWarningSeconds == 0 ? "The eye in the menu bar fills for the last minute." : nil,
                      selection: $settings.preBreakWarningSeconds) {
                Text("Menu Bar Only").tag(0)
                ForEach([5, 10, 30], id: \.self) { Text(verbatim: SettingsFormat.seconds($0)).tag($0) }
            }
        }
    }

    /// "Every 3rd Break"; in Arabic an ordinal word, which the number formatter doesn't give:
    /// "كل ثالث استراحة", "كل ثاني استراحة" (every other).
    static func everyNth(_ value: Int) -> String {
        let ordinal: String
        let arabicOrdinals = [2: "ثاني", 3: "ثالث", 4: "رابع", 5: "خامس", 6: "سادس", 7: "سابع", 8: "ثامن"]
        if L10n.appLanguage == "ar", let word = arabicOrdinals[value] {
            ordinal = word
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            ordinal = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return String(localized: "Every \(ordinal) Break")
    }

    // MARK: - Goal
    private var goal: some View {
        let scheduled = activity.scheduledBreaks
        return SettingsSection(title: "Daily goal") {
            ToggleRow(
                title: "Follow my shift",
                subtitle: .verbatim(String(localized: "\(activity.breakGoal) of the \(scheduled) breaks in a \(shift.schedule.durationText) shift, so a few skipped still counts as a good day.")),
                isOn: $settings.breakGoalFollowsShift
            )
            if !settings.breakGoalFollowsShift {
                StepperRow(title: "Breaks a day", valueText: String(localized: "\(settings.dailyBreakGoal) breaks"),
                           value: $settings.dailyBreakGoal, range: 1...60)
            }
        }
    }

    // MARK: - Blink reminders
    private var blinks: some View {
        SettingsSection(title: "Between breaks", footer: "Every break already ends with two full blinks. These are for days your eyes feel dry.") {
            ToggleRow(title: "Blink reminders", subtitle: "A small, silent reminder that fades on its own.", isOn: $settings.ambientRemindersEnabled)
            if settings.ambientRemindersEnabled {
                SliderRow(title: "Every", value: $settings.ambientReminderIntervalMinutes, range: 5...30, step: 5, format: SettingsFormat.minutes)
                ActionRow(title: "See one", button: "Show Now", action: showBlinkNow)
            }
        }
    }

    // MARK: - Away
    private var away: some View {
        SettingsSection(title: "Away", footer: "When you step away or lock the screen, EyeBreak pauses. The timer starts fresh when you're back, since you already rested.") {
            ToggleRow(title: "Pause when I'm away", isOn: $settings.idleDetectionEnabled)
            if settings.idleDetectionEnabled {
                SliderRow(title: "Away after", value: $settings.idleThresholdMinutes, range: 1...30, format: SettingsFormat.minutes)
            }
        }
    }

    // MARK: - History
    /// The month as bars: a line can't carry a month of counts.
    private var history: some View {
        let series = stats.series(days: 30)
        let taken = String(localized: "Taken")
        let skipped = String(localized: "Skipped")
        let workdays = shift.schedule.weekdays

        return Group {
            SettingsSection(title: "Last 30 days", footer: "Breaks taken each day, with skipped ones on top. The dashed line is the daily goal.") {
                if series.allSatisfy({ $0.total == 0 }) {
                    Text("Your days will fill in here from the first break you take.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Page.secondaryInk)
                        .padding(.vertical, 12)
                } else {
                    Chart {
                        ForEach(series) { day in
                            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Breaks", day.breaksCompleted))
                                .foregroundStyle(by: .value("Type", taken))
                            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Breaks", day.breaksSkipped))
                                .foregroundStyle(by: .value("Type", skipped))
                        }
                        RuleMark(y: .value("Goal", activity.breakGoal))
                            .foregroundStyle(Theme.Page.secondaryInk)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    .chartForegroundStyleScale([taken: Theme.accent, skipped: Theme.Page.secondaryInk.opacity(0.4)])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 170)
                    .padding(.vertical, 12)
                }
            }

            SettingsSection(title: "What the week says") {
                ForEach(stats.insights(goal: activity.breakGoal, workdays: workdays)) { insight in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(insight.tone == .positive ? Theme.onPage : Theme.Page.secondaryInk)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Page.ink)
                            Text(insight.message)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Page.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
