import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var stats: StatsStore
    @ObservedObject var settings: AppSettings

    enum Range: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
    }

    @State private var range: Range = .week
    @State private var confirmingReset = false

    var body: some View {
        SettingsPage(title: "Statistics") {
            todaySection
            historySection
            insightsSection

            Section {
                Button("Reset Statistics…", role: .destructive) { confirmingReset = true }
            } footer: {
                Text("All data stays on your Mac.")
            }
        }
        .alert("Reset all statistics?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { stats.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your break history will be permanently deleted.")
        }
    }

    // MARK: - Today
    private var todaySection: some View {
        let today = stats.today
        let goal = max(settings.dailyBreakGoal, 1)
        let change = today.breaksCompleted - stats.yesterday.breaksCompleted

        return Section("Today") {
            LabeledContent("Daily goal") {
                HStack(spacing: 10) {
                    ProgressView(value: min(Double(today.breaksCompleted) / Double(goal), 1))
                        .frame(width: 140)
                    Text("\(today.breaksCompleted) of \(goal)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Breaks taken") {
                HStack(spacing: 6) {
                    Text("\(today.breaksCompleted)").monospacedDigit()
                    if change != 0 {
                        Text("· \(abs(change)) \(change > 0 ? "more" : "fewer") than yesterday")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            LabeledContent("Skipped", value: "\(today.breaksSkipped)")
            LabeledContent("Time resting", value: SettingsFormat.duration(today.totalBreakTime))
            LabeledContent("Streak", value: stats.streak == 1 ? "1 day" : "\(stats.streak) days")
        }
    }

    // MARK: - History
    private var historySection: some View {
        let series = stats.series(days: range.days)

        return Section {
            Picker("Range", selection: $range) {
                ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Chart {
                ForEach(series) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Breaks", day.breaksCompleted))
                        .foregroundStyle(by: .value("Type", "Taken"))
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Breaks", day.breaksSkipped))
                        .foregroundStyle(by: .value("Type", "Skipped"))
                }
                RuleMark(y: .value("Goal", settings.dailyBreakGoal))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartForegroundStyleScale(["Taken": Theme.accent, "Skipped": Color.secondary.opacity(0.4)])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in
                    AxisValueLabel(format: range == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 180)
            .padding(.vertical, 4)
        } header: {
            Text("History")
        } footer: {
            Text("The dashed line is your daily goal.")
        }
    }

    // MARK: - Insights
    private var insightsSection: some View {
        Section("Insights") {
            ForEach(stats.insights(goal: settings.dailyBreakGoal)) { insight in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: insight.icon)
                        .foregroundStyle(insight.tone == .warning ? Theme.alert : Color.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                        Text(insight.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
