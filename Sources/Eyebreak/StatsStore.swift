import Foundation

/// One day of break history. Field names and the default `Date` encoding match
/// EyeBreak 2.2.0's `breakStatistics`, so existing history loads unchanged.
struct DayStats: Codable, Identifiable, Equatable {
    var date: Date
    var breaksCompleted: Int
    var totalBreakTime: TimeInterval
    var breaksSkipped: Int

    var id: Date { date }
    var total: Int { breaksCompleted + breaksSkipped }

    static func empty(_ date: Date) -> DayStats {
        DayStats(date: date, breaksCompleted: 0, totalBreakTime: 0, breaksSkipped: 0)
    }
}

struct Insight: Identifiable {
    enum Tone { case positive, warning, neutral }
    let icon: String
    let title: String
    let message: String
    let tone: Tone
    var id: String { title }
}

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    private let key = "breakStatistics"
    private let calendar = Calendar.current

    /// Newest first, one entry per day.
    @Published private(set) var days: [DayStats]
    /// When a day begins, in minutes after midnight, so a night shift stays one day. Set
    /// from the shift.
    var dayStartMinutes = 0

    /// The start of the day `date` belongs to.
    private func dayKey(_ date: Date) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(-Double(dayStartMinutes) * 60))
    }

    private init() {
        days = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([DayStats].self, from: $0) } ?? []
        days.sort { $0.date > $1.date }
    }

    // MARK: - Recording
    func recordCompleted(duration: TimeInterval) {
        updateToday { $0.breaksCompleted += 1; $0.totalBreakTime += duration }
    }

    func recordSkipped() {
        updateToday { $0.breaksSkipped += 1 }
    }

    func reset() {
        days = []
        save()
    }

    private func updateToday(_ change: (inout DayStats) -> Void) {
        let today = dayKey(Date())
        if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            change(&days[index])
        } else {
            var entry = DayStats.empty(today)
            change(&entry)
            days.insert(entry, at: 0)
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(days), forKey: key)
    }

    // MARK: - Queries
    var today: DayStats { stats(for: Date()) }
    var yesterday: DayStats { stats(for: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) }

    func stats(for date: Date) -> DayStats {
        let key = dayKey(date)
        return days.first { calendar.isDate($0.date, inSameDayAs: key) } ?? .empty(key)
    }

    /// Oldest → newest, with empty days filled in.
    func series(days count: Int) -> [DayStats] {
        let today = dayKey(Date())
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(stats(for:))
        }
    }

    /// Work days in a row with at least one break, days off skipped and one miss a week
    /// forgiven (`Streak`).
    func streak(workdays: Set<Int>) -> Int {
        let withBreaks = Set(days.filter { $0.breaksCompleted > 0 }.map { calendar.startOfDay(for: $0.date) })
        return Streak.workDays(withBreaks: withBreaks, workdays: workdays, today: dayKey(Date()), calendar: calendar)
    }

    /// What the last week says, in plain facts: no praise, no scolding.
    func insights(goal: Int, workdays: Set<Int>) -> [Insight] {
        let week = series(days: 7).filter { $0.total > 0 }
        var result: [Insight] = []

        if !week.isEmpty {
            let metGoal = week.filter { $0.breaksCompleted >= goal }.count
            result.append(Insight(
                icon: "target",
                title: String(localized: "Goal met on \(metGoal) of \(week.count) days"),
                message: String(localized: "Most of the breaks in your shift, \(goal) a day."),
                tone: metGoal * 10 >= week.count * 7 ? .positive : .neutral
            ))

            let completed = week.reduce(0) { $0 + $1.breaksCompleted }
            let skipped = week.reduce(0) { $0 + $1.breaksSkipped }
            if skipped * 4 >= (completed + skipped) {
                result.append(Insight(
                    icon: "forward",
                    title: String(localized: "\(skipped) of \(completed + skipped) breaks skipped this week"),
                    message: String(localized: "\"5 More Minutes\" holds a break back without skipping it."),
                    tone: .neutral
                ))
            }
        }

        let streak = streak(workdays: workdays)
        if streak >= 2 {
            result.append(Insight(
                icon: "calendar",
                title: String(localized: "\(streak) work days in a row"),
                message: String(localized: "Days off don't count, and one missed day a week is forgiven."),
                tone: .positive
            ))
        }

        if result.isEmpty {
            result.append(Insight(icon: "clock", title: String(localized: "No breaks recorded yet"),
                                  message: String(localized: "Finish a break and your history starts here."), tone: .neutral))
        }
        return result
    }
}
