import SwiftUI

/// Today's two rhythm lines, eyes over water, each with its symbol and count, in the menu.
struct RhythmLanes: View {
    @ObservedObject var activity: ActivityModel
    let now: Date
    var waterGoalML: Int
    var waterUnit: WaterUnit

    var body: some View {
        let window = activity.window(on: now)
        VStack(alignment: .leading, spacing: 4) {
            lane(.eyes, window: window, value: String(localized: "\(activity.log.count(.breakTaken, on: now)) of \(activity.breakGoal)"))
            lane(.water, window: window, value: WaterAmount.progress(activity.log.waterML(on: now), of: waterGoalML, unit: waterUnit))
        }
    }

    private func lane(_ habit: Habit, window: DateInterval, value: String) -> some View {
        let misses = activity.misses(habit, on: now)
        return HStack(spacing: 12) {
            Image(systemName: habit.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(habit.color(fullColor: true))
                .frame(width: 18, alignment: .leading)

            RhythmLine(misses: misses, window: window, now: now, color: habit.color(fullColor: true),
                       lineWidth: 1.75, trackColor: Color.primary.opacity(0.12))
                .frame(height: 24)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 78, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(habit.title): \(value), \(Rhythm.summary(misses: misses.count).lowercased())"))
    }
}

/// One habit's rhythm at the top of its Settings page: today's line with the count and the
/// shift's hours under it, then the last seven days.
struct HabitRhythm: View {
    let habit: Habit
    @ObservedObject var activity: ActivityModel
    let now: Date
    /// "9 of 16", "1.25 of 2 L"
    let value: String

    private let labelWidth: CGFloat = 76
    private let valueWidth: CGFloat = 96
    private var color: Color { habit.color(fullColor: true) }

    var body: some View {
        let window = activity.window(on: now)
        let misses = activity.misses(habit, on: now)
        let scores = activity.weekScores(habit)
        let recorded = scores.compactMap { $0 }
        let weekValue = recorded.isEmpty ? "—" : (recorded.reduce(0, +) / Double(recorded.count)).formatted(.percent.precision(.fractionLength(0)))

        VStack(alignment: .leading, spacing: 6) {
            row("Today", value: value) {
                RhythmLine(misses: misses, window: window, now: now, color: color, lineWidth: 2)
                    .frame(height: 34)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(String(localized: "Today")): \(value), \(Rhythm.summary(misses: misses.count).lowercased())"))

            HStack {
                Text(hour(window.start))
                Spacer()
                Text(hour(window.end))
            }
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Theme.Page.secondaryInk)
            .padding(.leading, labelWidth + 12)
            .padding(.trailing, valueWidth + 12)
            .accessibilityHidden(true)

            row("This week", value: weekValue) {
                WeekLine(scores: scores, color: color)
                    .frame(height: 34)
            }
            .padding(.top, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(String(localized: "This week")): \(weekValue)"))

            WeekLabels(labels: weekdays)
                .padding(.leading, labelWidth + 12)
                .padding(.trailing, valueWidth + 12)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
    }

    private func row<Line: View>(_ label: LocalizedStringKey, value: String, @ViewBuilder line: () -> Line) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Page.secondaryInk)
                .frame(width: labelWidth, alignment: .leading)
            line()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.Page.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: valueWidth, alignment: .trailing)
        }
    }

    /// The days of the week ending today, by the day a shift belongs to.
    private var weekdays: [String] {
        let calendar = Calendar.current
        let today = activity.log.dayKey(now)
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { calendar.shortWeekdaySymbols[calendar.component(.weekday, from: $0) - 1] }
        }
    }

    private func hour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter.string(from: date)
    }
}
