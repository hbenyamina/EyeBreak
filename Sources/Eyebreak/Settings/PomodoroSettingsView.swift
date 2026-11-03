import Charts
import SwiftUI

/// Pomodoro: what's running now, what today and the week held, then the four things you'd
/// come to change. The long break's length waits under More options.
struct PomodoroSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsStore
    /// Observed by the row that shows it, so the countdown redraws that row, not the page
    let timerManager: TimerManager

    var body: some View {
        let today = stats.today
        let week = stats.series(days: 7)
        let weekCount = week.reduce(0) { $0 + $1.pomodorosCompleted }

        SettingsPage(pane: .pomodoro) {
            SettingsSection(title: "Today") {
                PomodoroNowRow(timerManager: timerManager)
                ValueRow(title: "Pomodoros done", value: today.pomodorosCompleted.formatted())
                ValueRow(title: "Time in focus", value: Self.focusText(today.focusTime))
            }

            SettingsSection(title: "This week", footer: "Pomodoros that ran their full length, each day.") {
                if weekCount == 0 {
                    Text("Your week fills in here from the first Pomodoro you finish.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Page.secondaryInk)
                        .padding(.vertical, 12)
                } else {
                    weekChart(week)
                    ValueRow(title: "Pomodoros done", value: weekCount.formatted())
                    ValueRow(title: "Time in focus", value: Self.focusText(week.reduce(0) { $0 + $1.focusTime }))
                }
            }

            SettingsSection(title: "Lengths", footer: "While one runs, its breaks take the place of your usual ones, each a chance to stand and refill your water.") {
                SliderRow(title: "Focus", value: $settings.pomodoroFocusMinutes, range: 10...60, step: 5, format: SettingsFormat.minutes)
                SliderRow(title: "Break", value: $settings.pomodoroBreakMinutes, range: 3...15, format: SettingsFormat.minutes)
                PickerRow(title: "Long break", selection: $settings.pomodoroLongBreakEvery) {
                    ForEach(2...6, id: \.self) { Text(verbatim: BreakSettingsView.everyNth($0)).tag($0) }
                }
                ToggleRow(title: "Start the next one by itself",
                          subtitle: "Off: after each break, start the next from the menu. Your usual breaks run in between.",
                          isOn: $settings.pomodoroAutoContinue)
            }

            MoreOptions {
                SettingsSection(title: "Long break") {
                    SliderRow(title: "Long break length", value: $settings.pomodoroLongBreakMinutes, range: 10...30, step: 5, format: SettingsFormat.minutes)
                }
            }
        }
    }

    /// The week as bars: a count a day, which a line can't carry.
    private func weekChart(_ week: [DayStats]) -> some View {
        let most = week.map(\.pomodorosCompleted).max() ?? 0
        let step = max(1, Int((Double(max(most, 4)) / 4).rounded(.up)))
        let top = max(most, 4).roundedUp(toMultipleOf: step)

        return Chart(week) { day in
            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Pomodoros", day.pomodorosCompleted))
                .foregroundStyle(Theme.accent)
        }
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(values: Array(stride(from: 0, through: top, by: step))) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
        .frame(height: 140)
        .padding(.vertical, 12)
        .accessibilityLabel(Text("Pomodoros each day this week"))
    }

    /// "1 h 40 min", or "0 min" before the first.
    static func focusText(_ seconds: TimeInterval) -> String {
        seconds < 60 ? String(localized: "\(0) min") : SettingsFormat.duration(seconds)
    }
}

/// What the Pomodoro is doing now, with the button that changes it.
private struct PomodoroNowRow: View {
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        SettingRow(title: "Right now", detail: .verbatim(state)) {
            HStack(spacing: 8) {
                if let pomodoro = timerManager.pomodoro {
                    if pomodoro.isWaiting {
                        Button("Start Next") { timerManager.startPomodoro() }
                            .disabled(timerManager.isOnBreak)
                    }
                    Button("Stop") { timerManager.stopPomodoro() }
                } else {
                    Button("Start") { timerManager.startPomodoro() }
                        .disabled(timerManager.isOnBreak)
                }
            }
            .controlSize(.small)
        }
    }

    private var state: String {
        guard let pomodoro = timerManager.pomodoro else {
            return String(localized: "Not running. Start one here or from the menu bar.")
        }
        if timerManager.pauseReason != nil { return String(localized: "Paused") }
        if timerManager.isPomodoroBreak {
            return String(localized: "On a break, \(TimerManager.format(timerManager.breakTimeRemaining)) left")
        }
        if pomodoro.isWaiting { return String(localized: "Ready for the next one") }
        return String(localized: "Pomodoro \(pomodoro.completed + 1), \(TimerManager.format(timerManager.timeRemaining)) left")
    }
}

private extension Int {
    func roundedUp(toMultipleOf step: Int) -> Int {
        (self + step - 1) / step * step
    }
}
