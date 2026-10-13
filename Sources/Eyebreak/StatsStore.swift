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
        let today = calendar.startOfDay(for: Date())
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
        days.first { calendar.isDate($0.date, inSameDayAs: date) } ?? .empty(calendar.startOfDay(for: date))
    }

    /// Oldest → newest, with empty days filled in.
    func series(days count: Int) -> [DayStats] {
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(stats(for:))
        }
    }

    /// Consecutive days with at least one completed break, counting back from today
    /// (or from yesterday if today has none yet).
    var streak: Int {
        var date = calendar.startOfDay(for: Date())
        if stats(for: date).breaksCompleted == 0 {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        var count = 0
        while stats(for: date).breaksCompleted > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }

    func insights(goal: Int) -> [Insight] {
        let week = series(days: 7).filter { $0.total > 0 }
        var result: [Insight] = []

        if !week.isEmpty {
            let metGoal = week.filter { $0.breaksCompleted >= goal }.count
            let daysLabel = week.count == 1 ? "day" : "days"
            if Double(metGoal) / Double(week.count) >= 0.7 {
                result.append(Insight(icon: "checkmark.circle", title: "Goal met on \(metGoal) of \(week.count) \(daysLabel)", message: "You're keeping up with \(goal) breaks a day.", tone: .positive))
            } else {
                result.append(Insight(icon: "target", title: "Goal met on \(metGoal) of \(week.count) \(daysLabel)", message: "Taking the breaks you'd otherwise skip is the quickest way to reach \(goal) a day.", tone: .neutral))
            }

            let completed = week.reduce(0) { $0 + $1.breaksCompleted }
            let skipped = week.reduce(0) { $0 + $1.breaksSkipped }
            let skipRate = Double(skipped) / Double(max(completed + skipped, 1))
            if skipRate >= 0.25 {
                result.append(Insight(icon: "exclamationmark.triangle", title: "\(Int(skipRate * 100))% of breaks skipped this week", message: "\(skipped) skipped, \(completed) taken.", tone: .warning))
            }
        }

        if streak >= 2 {
            result.append(Insight(icon: "calendar", title: "\(streak) days in a row", message: "At least one break every day.", tone: .positive))
        }

        if result.isEmpty {
            result.append(Insight(icon: "clock", title: "No breaks recorded yet", message: "Finish a break and your history starts here.", tone: .neutral))
        }
        return result
    }
}
