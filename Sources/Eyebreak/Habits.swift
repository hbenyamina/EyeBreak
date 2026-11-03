import Foundation

// The rules behind a break and the day's feedback, kept to Foundation so the tests can
// compile them. Why each rule is what it is: docs/EVIDENCE.md.

// MARK: - The break routine

/// What a break asks of you at a given moment. A short break: look across the room, then
/// close your eyes, squeeze gently and open, twice (complete blinks; Kim 2021, Wolffsohn
/// 2025). A long break: stand up, refill your water, look out of a window, and the same
/// two blinks to finish.
enum BreakStep: Equatable {
    case lookAway
    case standUp
    case blink(cycle: Int, of: Int, phase: BlinkPhase)

    enum BlinkPhase: Equatable { case close, squeeze, open }

    var title: String {
        switch self {
        case .lookAway: return String(localized: "Look across the room")
        case .standUp: return String(localized: "Stand up and move")
        case .blink(_, _, .close): return String(localized: "Close your eyes")
        case .blink(_, _, .squeeze): return String(localized: "Squeeze gently")
        case .blink(_, _, .open): return String(localized: "Open slowly")
        }
    }

    var detail: String {
        switch self {
        case .lookAway: return String(localized: "Find something 3 metres away or more: a window, a doorway, the far wall.")
        case .standUp: return String(localized: "Refill your water and look out of a window for a while.")
        case let .blink(cycle, total, _): return total > 1 ? String(localized: "Slow blink \(cycle) of \(total)") : String(localized: "One slow, full blink")
        }
    }

    var symbol: String {
        switch self {
        case .lookAway: return "binoculars"
        case .standUp: return "figure.walk"
        case .blink(_, _, .open): return "eye"
        case .blink: return "eye.slash"
        }
    }

    var isBlink: Bool {
        if case .blink = self { return true }
        return false
    }
}

enum BreakGuide {
    /// One complete blink: 2 s closed, 2 s squeezing, 1 s to open.
    static let blinkCycle: TimeInterval = 5
    static let blinks = 2

    /// Two blinks when the break leaves time to look away first, one in a short break,
    /// none in a very short one.
    static func blinkCycles(for duration: TimeInterval) -> Int {
        duration >= 20 ? blinks : duration >= 10 ? 1 : 0
    }

    /// The step `elapsed` seconds into a break of `duration`. The blinks close the break.
    static func step(elapsed: TimeInterval, duration: TimeInterval, isLong: Bool) -> BreakStep {
        let cycles = blinkCycles(for: duration)
        let blinkStart = duration - Double(cycles) * blinkCycle
        guard cycles > 0, elapsed >= blinkStart else { return isLong ? .standUp : .lookAway }
        let into = elapsed - blinkStart
        let cycle = min(Int(into / blinkCycle), cycles - 1)
        let t = into - Double(cycle) * blinkCycle
        let phase: BreakStep.BlinkPhase = t < 2 ? .close : t < 4 ? .squeeze : .open
        return .blink(cycle: cycle + 1, of: cycles, phase: phase)
    }
}

// MARK: - Daily break goal

/// The day's break goal, from the shift: three quarters of the breaks it holds, so a day
/// with a few skipped still meets it.
enum BreakGoal {
    /// Breaks in `shiftMinutes` of work at this rhythm, long breaks included.
    static func scheduled(shiftMinutes: Int, workMinutes: Int, breakSeconds: Int, longEvery: Int, longMinutes: Int) -> Int {
        let work = Double(max(workMinutes, 1))
        let short = Double(breakSeconds) / 60
        // The average break, with every Nth one long
        let averageBreak = longEvery > 0
            ? (short * Double(longEvery - 1) + Double(longMinutes)) / Double(longEvery)
            : short
        return Int(Double(max(shiftMinutes, 0)) / (work + averageBreak))
    }

    static func fromShift(shiftMinutes: Int, workMinutes: Int, breakSeconds: Int, longEvery: Int, longMinutes: Int) -> Int {
        let breaks = scheduled(shiftMinutes: shiftMinutes, workMinutes: workMinutes, breakSeconds: breakSeconds,
                               longEvery: longEvery, longMinutes: longMinutes)
        return max(Int((Double(breaks) * 0.75).rounded()), 1)
    }
}

// MARK: - Streak

/// Work days in a row with at least one break. Days off don't count either way, today
/// doesn't break it while it's still under way, and one missed work day in any seven is
/// forgiven: a single miss doesn't undo a habit (Lally 2010), and a broken streak puts
/// people off more than a repairable one (Silverman & Barasch 2023).
enum Streak {
    static func workDays(withBreaks days: Set<Date>, workdays: Set<Int>, today: Date,
                         calendar: Calendar, graceEvery: Int = 7) -> Int {
        guard let earliest = days.min() else { return 0 }
        var day = calendar.startOfDay(for: today)
        let start = day
        var count = 0
        var walked = 0
        var lastGrace: Int?

        while day >= calendar.startOfDay(for: earliest) {
            defer { day = calendar.date(byAdding: .day, value: -1, to: day) ?? earliest.addingTimeInterval(-1) }
            let weekday = calendar.component(.weekday, from: day)
            guard workdays.isEmpty || workdays.contains(weekday) else { continue }

            if days.contains(day) {
                count += 1
                walked += 1
            } else if day == start {
                continue   // today, still under way
            } else if count > 0 || walked == 0, lastGrace.map({ walked - $0 >= graceEvery }) ?? true {
                lastGrace = walked
                walked += 1
            } else {
                break
            }
        }
        return count
    }
}
