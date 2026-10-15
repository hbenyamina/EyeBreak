import Darwin
import Foundation

// MARK: - Events

/// One moment of keeping up, or not: a break taken or skipped, a glass drunk or missed.
struct ActivityEvent: Codable, Hashable {
    enum Kind: String, Codable {
        case breakTaken, breakSkipped, drank, waterMissed

        var habit: Habit { self == .breakTaken || self == .breakSkipped ? .eyes : .water }
        var isMiss: Bool { self == .breakSkipped || self == .waterMissed }
    }

    var date: Date
    var kind: Kind
    /// Millilitres, for a glass drunk.
    var amount: Int? = nil
}

/// The two habits the rhythm lines follow.
enum Habit: String, CaseIterable, Codable {
    case eyes, water
}

/// What the app shares with the Rhythm widget: recent events and the day's goals, in
/// `~/Library/Application Support/EyeBreak/activity.json`. The app writes it on every
/// event; the widget only reads it, through the same sandbox exception as the shift file.
struct ActivityLog: Codable, Equatable {
    /// Oldest first, trimmed to the last `keepDays` days.
    var events: [ActivityEvent] = []
    var breakGoal: Int = 15
    var waterGoalML: Int = 2000
    /// The glass "I drank" adds, which sets how far behind counts as a missed glass.
    var glassML: Int = 250
    var waterUnit: WaterUnit = .milliliters
    /// The app theme, so the widget wears the same colours.
    var appTheme: AppTheme = .classic
    /// Today's shift, when there is one, so the widget draws the same span as the app.
    var shiftStart: Date?
    var shiftEnd: Date?
    /// When a day begins, in minutes after midnight: 0, or the middle of the time off for a
    /// night shift, so a shift that runs past midnight stays one day.
    var dayStartMinutes: Int = 0
    /// The app's language ("ar", "en"), so the widgets speak it too.
    var language: String?

    static let keepDays = 8

    init() {}

    private enum CodingKeys: String, CodingKey {
        case events, breakGoal, waterGoalML, glassML, waterUnit, appTheme, shiftStart, shiftEnd, dayStartMinutes, language
    }

    /// Every key is optional: a file written by an older or newer build still loads, keeping
    /// its events, rather than failing and starting the day's history over.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = (try? container.decodeIfPresent([ActivityEvent].self, forKey: .events)) ?? []
        breakGoal = (try? container.decodeIfPresent(Int.self, forKey: .breakGoal)) ?? 15
        waterGoalML = (try? container.decodeIfPresent(Int.self, forKey: .waterGoalML)) ?? 2000
        glassML = (try? container.decodeIfPresent(Int.self, forKey: .glassML)) ?? 250
        waterUnit = (try? container.decodeIfPresent(WaterUnit.self, forKey: .waterUnit)) ?? .milliliters
        appTheme = (try? container.decodeIfPresent(AppTheme.self, forKey: .appTheme)) ?? .classic
        shiftStart = try? container.decodeIfPresent(Date.self, forKey: .shiftStart)
        shiftEnd = try? container.decodeIfPresent(Date.self, forKey: .shiftEnd)
        dayStartMinutes = (try? container.decodeIfPresent(Int.self, forKey: .dayStartMinutes)) ?? 0
        language = try? container.decodeIfPresent(String.self, forKey: .language)
    }

    mutating func record(_ kind: ActivityEvent.Kind, amount: Int? = nil, at date: Date = Date(), calendar: Calendar = .current) {
        events.append(ActivityEvent(date: date, kind: kind, amount: amount))
        events.sort { $0.date < $1.date }
        if let cutoff = calendar.date(byAdding: .day, value: -Self.keepDays, to: calendar.startOfDay(for: date)) {
            events.removeAll { $0.date < cutoff }
        }
    }

    // MARK: Days

    /// The day `date` belongs to, as the start of a calendar day: the calendar day itself,
    /// or for a night shift the day its shift began.
    func dayKey(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(-Double(dayStartMinutes) * 60))
    }

    func events(on day: Date, calendar: Calendar = .current) -> [ActivityEvent] {
        events(inDay: dayKey(day, calendar: calendar), calendar: calendar)
    }

    private func events(inDay key: Date, calendar: Calendar) -> [ActivityEvent] {
        events.filter { dayKey($0.date, calendar: calendar) == key }
    }

    func count(_ kind: ActivityEvent.Kind, on day: Date, calendar: Calendar = .current) -> Int {
        events(on: day, calendar: calendar).filter { $0.kind == kind }.count
    }

    /// Millilitres drunk on `day`; a glass recorded without an amount counts 250 ml.
    func waterML(on day: Date, calendar: Calendar = .current) -> Int {
        events(on: day, calendar: calendar).filter { $0.kind == .drank }.reduce(0) { $0 + ($1.amount ?? 250) }
    }

    /// The span the lines are drawn across on `day`: the stored shift only when it belongs
    /// to that day (a file written yesterday still holds yesterday's shift).
    func window(on day: Date, calendar: Calendar = .current) -> DateInterval {
        let key = dayKey(day, calendar: calendar)
        let shiftIsToday = shiftStart.map { dayKey($0, calendar: calendar) == key } ?? false
        return Rhythm.window(shiftStart: shiftIsToday ? shiftStart : nil,
                             shiftEnd: shiftIsToday ? shiftEnd : nil,
                             events: events(inDay: key, calendar: calendar), day: key, calendar: calendar)
    }

    // MARK: Misses

    /// Where the line catches, up to `moment`: each skipped break; for water, each time the
    /// day fell a glass behind an even pace (a single "not now" isn't a miss on its own).
    func misses(_ habit: Habit, on moment: Date, calendar: Calendar = .current) -> [Date] {
        let todays = events(on: moment, calendar: calendar)
        switch habit {
        case .eyes:
            return todays.filter { $0.kind == .breakSkipped }.map(\.date)
        case .water:
            let drinks = todays.filter { $0.kind == .drank }.map { (date: $0.date, ml: $0.amount ?? 250) }
            return Rhythm.paceMisses(drinks: drinks, goal: waterGoalML, glass: glassML,
                                     window: window(on: moment, calendar: calendar), until: moment)
        }
    }

    /// Oldest first: each of the `days` days up to the one holding `moment`, scored for one
    /// habit. Today is scored against the pace so far, not the whole day's goal.
    func weekScores(_ habit: Habit, endingOn moment: Date, days: Int = 7, calendar: Calendar = .current) -> [Double?] {
        let last = dayKey(moment, calendar: calendar)
        return (0..<days).reversed().map { offset in
            guard let key = calendar.date(byAdding: .day, value: -offset, to: last) else { return nil }
            let dayEvents = events(inDay: key, calendar: calendar)
            switch habit {
            case .eyes:
                return Rhythm.score(.eyes, events: dayEvents)
            case .water:
                guard dayEvents.contains(where: { $0.kind.habit == .water }) else { return nil }
                let drunk = dayEvents.filter { $0.kind == .drank }.reduce(0) { $0 + ($1.amount ?? 250) }
                // A past day is judged on the whole goal; today on the share due so far
                var fraction = 1.0
                if offset == 0 {
                    let span = window(on: moment, calendar: calendar)
                    fraction = min(max(moment.timeIntervalSince(span.start) / span.duration, 0), 1)
                }
                return Rhythm.waterScore(drunk: drunk, goal: waterGoalML, fractionOfDay: fraction)
            }
        }
    }
}

extension ShiftSchedule {
    /// Where a day begins for this shift, in minutes after midnight: midnight for a day
    /// shift; for one that runs past midnight, the middle of the time off, so the whole
    /// shift falls in the day it started.
    var dayStartMinutes: Int {
        guard endMinutes <= startMinutes, durationMinutes < 1440 else { return 0 }
        return (endMinutes + startMinutes) / 2
    }
}

enum ActivityStore {
    static let fileName = "activity.json"

    private static var fileURL: URL {
        var home = FileManager.default.homeDirectoryForCurrentUser
        // The real home, also inside the widget's sandbox (see ShiftStore)
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            home = URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return home
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(ShiftStore.directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func load() -> ActivityLog {
        guard let data = try? Data(contentsOf: fileURL),
              let log = try? JSONDecoder().decode(ActivityLog.self, from: data) else { return ActivityLog() }
        return log
    }

    static func save(_ log: ActivityLog) {
        guard let data = try? JSONEncoder().encode(log) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Rhythm

/// The rhythm line: a habit drawn across the day as a straight line along the top while
/// you keep up, which catches at each miss — dropping sharply at that moment and easing
/// back over the next while. Misses close together pull it further down.
enum Rhythm {
    /// How far one miss pulls the line down, out of the full height.
    static let missDepth = 0.42
    /// Never touches the floor, so the line stays a line.
    static let floor = 0.06

    /// The span the lines are drawn across: today's shift when there is one, widened to
    /// take in anything recorded outside it; otherwise 8 AM to 8 PM, likewise widened.
    static func window(shiftStart: Date?, shiftEnd: Date?, events: [ActivityEvent], day: Date, calendar: Calendar = .current) -> DateInterval {
        var start = shiftStart ?? calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
        var end = shiftEnd ?? calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day.addingTimeInterval(12 * 3600)
        if let first = events.first?.date, first < start { start = first }
        if let last = events.last?.date, last > end { end = last }
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
    }

    /// Height of the line at `date`, 1 on track, sinking toward `floor` around misses.
    static func level(at date: Date, misses: [Date], span: TimeInterval) -> Double {
        // The catch scales with the span: about 1% of it to drop, 9% to recover
        // (5 and 45 minutes on an 8-hour shift).
        let drop = max(span * 0.01, 60)
        let recover = max(span * 0.09, 600)
        var pull = 0.0
        for miss in misses {
            let t = date.timeIntervalSince(miss)
            if t < 0 || t > drop + recover { continue }
            let shape = t < drop
                ? t / drop
                : 0.5 * (1 + cos(.pi * (t - drop) / recover))   // eases back to the line
            pull += missDepth * shape
        }
        return max(1 - pull, floor)
    }

    /// Sample points (x 0…1 across `window`, y 1 at the top) from the window's start up to
    /// `now`. Nothing is drawn for time that hasn't happened yet.
    static func points(misses: [Date], window: DateInterval, now: Date, samples: Int = 120) -> [(x: Double, y: Double)] {
        let span = window.duration
        guard span > 0 else { return [] }
        let end = min(max(now, window.start), window.end)
        let fraction = end.timeIntervalSince(window.start) / span
        guard fraction > 0 else { return [] }
        let count = max(2, Int(Double(samples) * fraction))
        var result: [(x: Double, y: Double)] = (0...count).map { step in
            let x = fraction * Double(step) / Double(count)
            return (x, level(at: window.start.addingTimeInterval(span * x), misses: misses, span: span))
        }
        // Each miss lands exactly on a sample, so the catch's corner isn't rounded away.
        for miss in misses where miss > window.start && miss < end {
            let x = miss.timeIntervalSince(window.start) / span
            result.append((x, level(at: miss, misses: misses, span: span)))
        }
        return result.sorted { $0.x < $1.x }
    }

    /// The day's score for one habit, 0…1: share of breaks taken, or glasses drunk out of
    /// glasses drunk plus missed. Nil when nothing happened. Water is usually scored with
    /// `waterScore` instead, against the goal.
    static func score(_ habit: Habit, events: [ActivityEvent]) -> Double? {
        let relevant = events.filter { $0.kind.habit == habit }
        guard !relevant.isEmpty else { return nil }
        let hits = relevant.filter { !$0.kind.isMiss }.count
        return Double(hits) / Double(relevant.count)
    }

    /// Water drunk against the share of the goal due by now (all of it, for a past day).
    static func waterScore(drunk: Int, goal: Int, fractionOfDay: Double) -> Double {
        let due = Double(max(goal, 1)) * fractionOfDay
        guard due > 0 else { return 1 }
        return min(Double(drunk) / due, 1)
    }

    /// The moments the day fell behind an even pace: the goal spread evenly across `window`.
    /// A glass behind is normal between reminders, so the first catch comes at a glass and
    /// a half behind and each further glass adds one; drinking to catch up clears them, and
    /// a later lag catches again. Drinks before the window count toward it.
    static func paceMisses(drinks: [(date: Date, ml: Int)], goal: Int, glass: Int, window: DateInterval,
                           until: Date, step: TimeInterval = 60) -> [Date] {
        guard goal > 0, glass > 0, window.duration > 0 else { return [] }
        let end = min(until, window.end)
        let sorted = drinks.sorted { $0.date < $1.date }
        var misses: [Date] = []
        var level = 0
        var drunk = 0
        var next = 0
        var t = window.start
        while t <= end {
            while next < sorted.count && sorted[next].date <= t {
                drunk += sorted[next].ml
                next += 1
            }
            let expected = Double(goal) * t.timeIntervalSince(window.start) / window.duration
            let behind = Int(((expected - Double(drunk)) / Double(glass) - 0.5).rounded(.down))
            if behind > level {
                misses.append(t)
                level = behind
            } else if behind < level {
                level = max(behind, 0)
            }
            t += step
        }
        return misses
    }

    /// "On track", "1 miss", "3 misses" — the words beside the lines.
    static func summary(misses: Int) -> String {
        switch misses {
        case 0: return String(shared: "On track")
        case 1: return String(shared: "1 miss")
        default: return String(shared: "\(misses) misses")
        }
    }
}
