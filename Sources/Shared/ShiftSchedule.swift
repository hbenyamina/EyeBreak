import Foundation

/// A shift that repeats at the same wall-clock time on a chosen set of weekdays.
///
/// The end time may be earlier than the start time, which means the shift runs past
/// midnight (a night shift). In that case the weekday set refers to the day the shift
/// *starts* on.
struct ShiftSchedule: Hashable, Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday).
    var weekdays: Set<Int>
    /// The zone the hours are read in. Nil follows this Mac, which already tracks
    /// whatever macOS is set to — including its "set time zone automatically using
    /// your current location" option.
    var timeZoneIdentifier: String?
    /// A one-off start for a single shift: the moment the Mac was unlocked on a day the
    /// user arrived late (or early). The shift it stands in for keeps its full length,
    /// so the end moves with it. It applies to that one occurrence only; a value from an
    /// earlier day is simply ignored, so it never needs clearing to stay correct.
    var adjustedStart: Date?

    init(startHour: Int,
         startMinute: Int,
         endHour: Int,
         endMinute: Int,
         weekdays: Set<Int>,
         timeZoneIdentifier: String? = nil,
         adjustedStart: Date? = nil) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.timeZoneIdentifier = timeZoneIdentifier
        self.adjustedStart = adjustedStart
    }

    /// 9 to 5 on the region's working days: Monday to Friday in most places, Sunday to
    /// Thursday where the weekend is Friday and Saturday.
    static var standard: ShiftSchedule {
        ShiftSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0, weekdays: regionWorkweek())
    }

    /// The weekdays (1 = Sunday … 7 = Saturday) that aren't the region's weekend.
    static func regionWorkweek(calendar: Calendar = .current) -> Set<Int> {
        // A week of real dates, so the calendar can say which fall on its weekend
        let start = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let working = days.filter { !calendar.isDateInWeekend($0) }.map { calendar.component(.weekday, from: $0) }
        return working.count >= 3 ? Set(working) : [2, 3, 4, 5, 6]
    }

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }

    /// Length of one shift, wrapping past midnight when the end is at or before the start.
    var durationMinutes: Int {
        let raw = endMinutes - startMinutes
        return raw > 0 ? raw : raw + 24 * 60
    }

    var followsSystemTimeZone: Bool { timeZoneIdentifier == nil }

    var timeZone: TimeZone {
        timeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
    }

    /// The calendar every date calculation here goes through: the user's calendar and
    /// locale, in the schedule's zone.
    var resolvedCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }
}

/// One concrete occurrence of a shift.
struct ShiftWindow: Hashable {
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

struct ShiftStatus: Hashable {
    enum Phase { case onShift, beforeShift, offDuty }

    /// Where we are relative to `window`.
    var phase: Phase
    /// The shift currently running, or the next one coming up.
    var window: ShiftWindow

    /// The moment the countdown is aimed at: the end of the running shift,
    /// or the start of the next one.
    var target: Date { phase == .onShift ? window.end : window.start }

    /// How much of the shift is done, 0-1, at `date`.
    func progress(at date: Date) -> Double {
        let total = window.end.timeIntervalSince(window.start)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(window.start) / total))
    }
}

extension ShiftSchedule {

    /// The occurrence that starts on `day`, or nil if the shift doesn't run that weekday.
    func window(startingOn day: Date, calendar: Calendar) -> ShiftWindow? {
        let midnight = calendar.startOfDay(for: day)
        guard let weekday = calendar.dateComponents([.weekday], from: midnight).weekday,
              weekdays.contains(weekday),
              let start = Self.date(hour: startHour, minute: startMinute, onDayOf: midnight, calendar: calendar)
        else { return nil }

        // Both ends are built from wall-clock components rather than by adding elapsed
        // minutes, so a shift that spans a daylight-saving change still ends at the time
        // on the clock — the same hour the worker actually goes home.
        let endsNextDay = endMinutes <= startMinutes
        let endDay = endsNextDay ? calendar.date(byAdding: .day, value: 1, to: midnight) : midnight
        let end = endDay
            .flatMap { Self.date(hour: endHour, minute: endMinute, onDayOf: $0, calendar: calendar) }
            ?? calendar.date(byAdding: .minute, value: durationMinutes, to: start)
        guard let end else { return nil }
        return ShiftWindow(start: start, end: max(end, start.addingTimeInterval(60)))
    }

    private static func date(hour: Int, minute: Int, onDayOf day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }

    /// The one-off occurrence `adjustedStart` describes: the shift's full length from
    /// that moment. Elapsed minutes rather than wall-clock components here, because the
    /// point is that the worker still puts in the whole shift.
    func adjustedWindow(calendar: Calendar? = nil) -> ShiftWindow? {
        guard let start = adjustedStart else { return nil }
        let calendar = calendar ?? resolvedCalendar
        let end = calendar.date(byAdding: .minute, value: durationMinutes, to: start)
            ?? start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        return ShiftWindow(start: start, end: max(end, start.addingTimeInterval(60)))
    }

    /// Every occurrence in a window of days around `date`, in chronological order, with
    /// the adjusted start (if it falls in that range) standing in for the scheduled shift.
    func windows(around date: Date, calendar: Calendar? = nil, days dayRange: ClosedRange<Int> = -2...9) -> [ShiftWindow] {
        let calendar = calendar ?? resolvedCalendar
        let today = calendar.startOfDay(for: date)
        var occurrences = dayRange.compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
                .flatMap { window(startingOn: $0, calendar: calendar) }
        }

        if let adjusted = adjustedWindow(calendar: calendar),
           let first = calendar.date(byAdding: .day, value: dayRange.lowerBound, to: today),
           let last = calendar.date(byAdding: .day, value: dayRange.upperBound + 1, to: today),
           adjusted.start >= first, adjusted.start < last {
            // It replaces the shift that was already running at that moment — the one the
            // worker was late for, which for a night shift may have started the day
            // before — or, if none was, whatever was scheduled that day. On a day off it
            // simply adds a shift.
            if let running = occurrences.firstIndex(where: { $0.contains(adjusted.start) }) {
                occurrences.remove(at: running)
            } else {
                occurrences.removeAll { calendar.isDate($0.start, inSameDayAs: adjusted.start) }
            }
            occurrences.append(adjusted)
        }
        return occurrences.sorted { $0.start < $1.start }
    }

    /// Whether we're on shift, waiting for today's shift, or off the clock.
    /// Nil only when no weekdays are selected.
    func status(at date: Date, calendar: Calendar? = nil) -> ShiftStatus? {
        let calendar = calendar ?? resolvedCalendar
        let occurrences = windows(around: date, calendar: calendar)
        if let running = occurrences.first(where: { $0.contains(date) }) {
            return ShiftStatus(phase: .onShift, window: running)
        }
        guard let next = occurrences.first(where: { $0.start > date }) else { return nil }
        let startsToday = calendar.isDate(next.start, inSameDayAs: date)
        return ShiftStatus(phase: startsToday ? .beforeShift : .offDuty, window: next)
    }

    /// Dates the widget needs a timeline entry for: every shift start and end, plus a
    /// tick through each shift so the progress bar advances.
    func timelineDates(from date: Date,
                       calendar: Calendar? = nil,
                       tick: TimeInterval = 15 * 60,
                       limit: Int = 120) -> [Date] {
        let calendar = calendar ?? resolvedCalendar
        var dates: Set<Date> = [date]
        for window in windows(around: date, calendar: calendar, days: -1...3) {
            dates.insert(window.start)
            dates.insert(window.end)
            var moment = window.start
            while moment < window.end {
                dates.insert(moment)
                moment += tick
            }
        }
        return dates.filter { $0 >= date }.sorted().prefix(limit).map { $0 }
    }
}

// MARK: - Display

extension ShiftSchedule {

    /// A wall-clock time such as "5:00 PM", in whichever format the user's locale uses.
    static func timeText(hour: Int, minute: Int, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        guard let date = calendar.date(from: components) else { return "\(hour):\(minute)" }
        return formatter.string(from: date)
    }

    var startText: String { Self.timeText(hour: startHour, minute: startMinute) }
    var endText: String { Self.timeText(hour: endHour, minute: endMinute) }

    /// A concrete moment as a wall-clock time in the schedule's zone, e.g. "9:24 AM".
    /// Displays use this for a window's real ends, which differ from `startText` and
    /// `endText` on a day the shift was started from an unlock.
    func clockText(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }

    /// "9:24 AM – 5:24 PM" for one occurrence.
    func rangeText(for window: ShiftWindow, locale: Locale = .current) -> String {
        "\(clockText(for: window.start, locale: locale)) – \(clockText(for: window.end, locale: locale))"
    }

    /// "8h" or "7h 30m"
    var durationText: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if minutes == 0 { return String(shared: "\(hours)h") }
        if hours == 0 { return String(shared: "\(minutes)m") }
        return String(shared: "\(hours)h \(minutes)m")
    }

    /// The city out of the zone identifier, e.g. "Riyadh". Nil when following the Mac.
    var timeZoneText: String? {
        guard let identifier = timeZoneIdentifier else { return nil }
        let city = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return city.replacingOccurrences(of: "_", with: " ")
    }

    /// An absolute moment on this Mac's clock — worth showing only when the shift is
    /// pinned to another zone.
    func systemClockText(for date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }

    /// True when the pinned zone is currently offset from this Mac's.
    func differsFromSystemClock(at date: Date = Date()) -> Bool {
        guard !followsSystemTimeZone else { return false }
        return timeZone.secondsFromGMT(for: date) != TimeZone.current.secondsFromGMT(for: date)
    }

    /// "Every day", "Mon–Fri", or "Mon, Wed, Fri".
    func daysText(calendar: Calendar? = nil) -> String {
        let calendar = calendar ?? resolvedCalendar
        guard !weekdays.isEmpty else { return String(shared: "No days") }
        guard weekdays.count < 7 else { return String(shared: "Every day") }

        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday
        // Walk the week in the locale's own order so "Sat–Sun" style runs stay contiguous.
        let ordered = (0..<7)
            .map { ((first - 1 + $0) % 7) + 1 }
            .filter { weekdays.contains($0) }
        let positions = ordered.map { ($0 - first + 7) % 7 }
        let isRun = zip(positions, positions.dropFirst()).allSatisfy { $1 == $0 + 1 }
        let name = { (weekday: Int) in symbols[weekday - 1] }

        if isRun && ordered.count > 2, let low = ordered.first, let high = ordered.last {
            return "\(name(low))–\(name(high))"
        }
        return ordered.map(name).joined(separator: ", ")
    }

    /// "9:00 AM – 5:00 PM · Mon–Fri"
    func summaryText(calendar: Calendar? = nil) -> String {
        "\(startText) – \(endText) · \(daysText(calendar: calendar))"
    }
}

extension Date {
    /// "today", "tomorrow", or a weekday such as "Mon".
    func weekdayText(calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDateInToday(self) { return String(shared: "today") }
        if calendar.isDateInTomorrow(self) { return String(shared: "tomorrow") }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: self)
    }
}
