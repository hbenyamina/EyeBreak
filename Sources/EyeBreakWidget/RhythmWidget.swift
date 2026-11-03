import SwiftUI
import WidgetKit

/// "How well am I doing?" for eye breaks and water: each habit a line across today's
/// shift, straight while you keep up and catching where you skipped a break or put off a
/// glass. The large size adds the last seven days.
struct RhythmWidget: Widget {
    /// Stable: changing it orphans every widget already on someone's desktop.
    static let kind = "RhythmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RhythmProvider()) { entry in
            RhythmWidgetView(entry: entry)
                .widgetURL(URL(string: "eyebreak://statistics"))
        }
        .configurationDisplayName("Rhythm")
        .description("How you're keeping up with breaks and water today: a straight line while you're on track, a dip where you fell behind.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RhythmEntry: TimelineEntry {
    let date: Date
    let log: ActivityLog
}

struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: Date(), log: ActivityLog())
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        let log = ActivityStore.load()
        Theme.current = log.appTheme
        L10n.follow(language: log.language)
        completion(RhythmEntry(date: Date(), log: log))
    }

    /// The app reloads this on every break and glass; in between, an entry every 15
    /// minutes moves "now" along the line.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        let now = Date()
        let log = ActivityStore.load()
        // The widget wears the app's theme and speaks its language, as the app last wrote them
        Theme.current = log.appTheme
        L10n.follow(language: log.language)
        let calendar = Calendar.current
        let window = log.window(on: now)
        var dates: [Date] = [now]
        var moment = now.addingTimeInterval(15 * 60)
        while moment < window.end && dates.count < 96 {
            dates.append(moment)
            moment += 15 * 60
        }
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(nextDay.addingTimeInterval(60))
        }
        completion(Timeline(entries: dates.map { RhythmEntry(date: $0, log: log) }, policy: .atEnd))
    }
}

// MARK: - Views

struct RhythmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: RhythmEntry

    private var isFullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        content
            .environment(\.layoutDirection, L10n.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, L10n.locale)
            .containerBackground(for: .widget) {
                if isFullColor { Theme.Page.paper } else { Color.clear }
            }
    }

    @ViewBuilder private var content: some View {
        let day = RhythmDay(log: entry.log, now: entry.date)
        switch family {
        case .systemSmall: RhythmSmall(day: day, fullColor: isFullColor)
        case .systemLarge: RhythmLarge(day: day, fullColor: isFullColor)
        default: RhythmMedium(day: day, fullColor: isFullColor)
        }
    }
}

/// Everything the layouts read, worked out once per entry.
struct RhythmDay {
    let log: ActivityLog
    let now: Date
    let window: DateInterval
    let eyeMisses: [Date]
    let waterMisses: [Date]
    let breaksTaken: Int
    let waterML: Int

    init(log: ActivityLog, now: Date) {
        self.log = log
        self.now = now
        window = log.window(on: now)
        eyeMisses = log.misses(.eyes, on: now)
        waterMisses = log.misses(.water, on: now)
        breaksTaken = log.count(.breakTaken, on: now)
        waterML = log.waterML(on: now)
    }

    var totalMisses: Int { eyeMisses.count + waterMisses.count }

    func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter.string(from: date)
    }
}

private struct Lane: View {
    let habit: Habit
    let day: RhythmDay
    let fullColor: Bool
    var lineWidth: CGFloat = 2

    var body: some View {
        RhythmLine(
            misses: habit == .eyes ? day.eyeMisses : day.waterMisses,
            window: day.window,
            now: day.now,
            color: habit.color(fullColor: fullColor),
            lineWidth: lineWidth,
            trackColor: fullColor ? Theme.Page.hairline : Color.primary.opacity(0.15)
        )
        .widgetAccentable()
    }
}

private struct HabitLabel: View {
    let habit: Habit
    let value: String
    let fullColor: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: habit.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(habit.color(fullColor: fullColor))
                .widgetAccentable()
            Text(habit.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(fullColor ? Theme.Page.secondaryInk : Color.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(fullColor ? Theme.Page.ink : Color.primary)
        }
    }
}

private struct Header: View {
    let title: String
    let day: RhythmDay
    let fullColor: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fullColor ? Theme.Page.ink : Color.primary)
            Spacer(minLength: 6)
            Text(Rhythm.summary(misses: day.totalMisses))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(fullColor ? Theme.Page.secondaryInk : Color.secondary)
        }
    }
}

private struct RhythmSmall: View {
    let day: RhythmDay
    let fullColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(title: String(shared: "Today"), day: day, fullColor: fullColor)
            Spacer(minLength: 8)
            HabitLabel(habit: .eyes, value: String(shared: "\(day.breaksTaken) of \(day.log.breakGoal)"), fullColor: fullColor)
            Lane(habit: .eyes, day: day, fullColor: fullColor)
                .frame(height: 26)
            Spacer(minLength: 8)
            HabitLabel(habit: .water, value: WaterAmount.progress(day.waterML, of: day.log.waterGoalML, unit: day.log.waterUnit), fullColor: fullColor)
            Lane(habit: .water, day: day, fullColor: fullColor)
                .frame(height: 26)
        }
    }
}

private struct RhythmMedium: View {
    let day: RhythmDay
    let fullColor: Bool
    /// On its own the medium centres its lanes; inside the large widget they sit right
    /// under the header, so the week can follow without a gap.
    var centred = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(title: String(shared: "Today's rhythm"), day: day, fullColor: fullColor)
            if centred {
                Spacer(minLength: 6)
                lanes
                Spacer(minLength: 0)
            } else {
                lanes
                    .padding(.top, 14)
            }
        }
    }

    var lanes: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(.eyes, value: String(shared: "\(day.breaksTaken) of \(day.log.breakGoal)"))
            row(.water, value: WaterAmount.progress(day.waterML, of: day.log.waterGoalML, unit: day.log.waterUnit))
            HStack {
                Text(day.timeText(day.window.start))
                Spacer()
                Text(day.timeText(day.window.end))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(fullColor ? Theme.Page.secondaryInk : Color.secondary)
            .padding(.leading, 58)
            .padding(.trailing, 86)
        }
    }

    private func row(_ habit: Habit, value: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: habit.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(habit.color(fullColor: fullColor))
                    .widgetAccentable()
                Text(habit.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(fullColor ? Theme.Page.secondaryInk : Color.secondary)
            }
            .frame(width: 48, alignment: .leading)

            Lane(habit: habit, day: day, fullColor: fullColor)
                .frame(height: 30)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(fullColor ? Theme.Page.ink : Color.primary)
                .frame(width: 76, alignment: .trailing)
        }
    }
}

private struct RhythmLarge: View {
    let day: RhythmDay
    let fullColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RhythmMedium(day: day, fullColor: fullColor, centred: false)

            Rectangle()
                .fill(fullColor ? Theme.Page.hairline : Color.primary.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 12)

            Text(String(shared: "This week"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fullColor ? Theme.Page.ink : Color.primary)
            Spacer(minLength: 8)
            week(.eyes)
            Spacer(minLength: 10)
            week(.water)
            Spacer(minLength: 6)
            WeekLabels(labels: weekdays, color: fullColor ? Theme.Page.secondaryInk : Color.secondary, size: 10)
                .padding(.leading, 58)
                .padding(.trailing, 86)
        }
    }

    private var weekdays: [String] {
        var calendar = Calendar.current
        calendar.locale = L10n.locale
        let today = day.log.dayKey(day.now)
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
                .map { calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: $0) - 1] }
        }
    }

    private func week(_ habit: Habit) -> some View {
        let scores = day.log.weekScores(habit, endingOn: day.now)
        let average = scores.compactMap { $0 }
        let value = average.isEmpty ? "—" : (average.reduce(0, +) / Double(average.count)).formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale))
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: habit.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(habit.color(fullColor: fullColor))
                Text(habit.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(fullColor ? Theme.Page.secondaryInk : Color.secondary)
            }
            .frame(width: 48, alignment: .leading)

            WeekLine(scores: scores, color: habit.color(fullColor: fullColor),
                     trackColor: fullColor ? Theme.Page.hairline : Color.primary.opacity(0.15))
                .frame(height: 34)
                .widgetAccentable()

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(fullColor ? Theme.Page.ink : Color.primary)
                .frame(width: 76, alignment: .trailing)
        }
    }
}
