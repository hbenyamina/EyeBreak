import AppKit
import Combine
import WidgetKit

/// The shift: the single copy of the hours that the menu bar, Settings, the Smart Schedule
/// pause and (through `ShiftStore`'s file) the End of Shift widget all read.
final class ShiftModel: ObservableObject {
    /// Editing either of these saves them and nudges the widget.
    @Published var schedule: ShiftSchedule {
        didSet { if schedule != oldValue { persist() } }
    }
    @Published var themeID: String {
        didSet { if themeID != oldValue { persist() } }
    }

    /// Ticks once a second to drive the live countdowns.
    @Published private(set) var now = Date()

    var theme: ShiftTheme { ShiftTheme.named(themeID) }
    var status: ShiftStatus? { schedule.status(at: now) }

    /// Where the hours came from on this launch, if they were carried over.
    enum Migration { case fromShiftCountdown, fromWorkHours }
    let migration: Migration?

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        migration = Self.migrateIfNeeded()
        let settings = ShiftStore.load()
        schedule = settings.schedule
        themeID = settings.themeID
        // Any launch re-syncs the widget, in case it was left holding older hours.
        WidgetCenter.shared.reloadAllTimelines()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.now = Date() }
        timer.tolerance = 0.2
        // .common so the countdowns keep moving while a menu is open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // A schedule that follows this Mac moves with it, so the widget needs to hear
        // about a zone change or a clock change too.
        for name in [NSNotification.Name.NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                WidgetCenter.shared.reloadAllTimelines()
            })
        }

        // A start from an earlier day has done its job. Dropping it keeps the shared file
        // tidy; the maths would ignore it either way.
        if let adjusted = schedule.adjustedWindow(), adjusted.end < now {
            schedule.adjustedStart = nil
        }
    }

    deinit {
        timer?.invalidate()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func persist() {
        ShiftStore.save(ShiftSettings(schedule: schedule, themeID: themeID))
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Migration

    /// First launch of the merged app: carry the hours over instead of starting from 9-to-5.
    /// Shift Countdown's file wins — it has minutes, time zones and today's late start —
    /// and EyeBreak's hour-only Smart Schedule is the fallback.
    private static func migrateIfNeeded() -> Migration? {
        guard !ShiftStore.exists else { return nil }
        if let legacy = ShiftStore.loadLegacy() {
            ShiftStore.save(legacy)
            return .fromShiftCountdown
        }
        // 2.2.0 / 3.0 keys, no longer written now the hours live in the shared file.
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "workHoursStart") != nil else { return nil }
        let days = defaults.data(forKey: "activeDays")
            .flatMap { try? JSONDecoder().decode([Int].self, from: $0) }
            .map(Set.init) ?? ShiftSchedule.standard.weekdays
        let schedule = ShiftSchedule.fromWorkHours(
            start: defaults.integer(forKey: "workHoursStart"),
            end: defaults.integer(forKey: "workHoursEnd"),
            days: days
        )
        ShiftStore.save(ShiftSettings(schedule: schedule, themeID: ShiftTheme.defaultID))
        return .fromWorkHours
    }

    // MARK: - Smart Schedule

    /// Breaks and reminders run while this is true, when the Smart Schedule is on.
    func isOnShift(at date: Date = Date()) -> Bool {
        schedule.status(at: date)?.phase == .onShift
    }

    // MARK: - Presets

    /// nil when the hours don't match one.
    var preset: SchedulePreset? {
        SchedulePreset.allCases.first {
            $0.hours.start == schedule.startHour && schedule.startMinute == 0
                && $0.hours.end == schedule.endHour && schedule.endMinute == 0
        }
    }

    func apply(_ preset: SchedulePreset) {
        schedule.startHour = preset.hours.start
        schedule.startMinute = 0
        schedule.endHour = preset.hours.end
        schedule.endMinute = 0
    }

    // MARK: - Starting from now

    /// Today's shift, if it was started from a moment rather than the scheduled time:
    /// the one running now, or the one that starts later today.
    var adjustedWindowToday: ShiftWindow? {
        guard let window = schedule.adjustedWindow() else { return nil }
        let calendar = schedule.resolvedCalendar
        let isToday = window.contains(now) || calendar.isDate(window.start, inSameDayAs: now)
        return isToday && window.end > now ? window : nil
    }

    /// The scheduled occurrence for today, for the "Today" row.
    var scheduledWindowToday: ShiftWindow? {
        schedule.window(startingOn: now, calendar: schedule.resolvedCalendar)
    }

    /// Start (or restart) today's shift from `moment`, keeping its length.
    func startShift(at moment: Date = Date()) {
        schedule.adjustedStart = moment
    }

    /// Back to the scheduled hours for today.
    func clearAdjustedStart() {
        schedule.adjustedStart = nil
    }

    /// "9:24 AM – 5:24 PM · started from now", or the scheduled hours, or no shift.
    var todayText: String {
        if let window = adjustedWindowToday {
            return "\(schedule.rangeText(for: window)) · started from now"
        }
        guard let window = scheduledWindowToday else { return "No shift today" }
        return window.end <= now ? "\(schedule.rangeText(for: window)) · over" : schedule.rangeText(for: window)
    }
}

/// The time zones offered in the picker, split into a region and a city so the list
/// stays navigable.
enum TimeZoneCatalog {
    static let regions: [String] = {
        var seen = Set<String>()
        for identifier in TimeZone.knownTimeZoneIdentifiers {
            seen.insert(region(of: identifier))
        }
        return seen.sorted()
    }()

    static func cities(in region: String) -> [(identifier: String, name: String)] {
        TimeZone.knownTimeZoneIdentifiers
            .filter { self.region(of: $0) == region }
            .map { (identifier: $0, name: city(of: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func region(of identifier: String) -> String {
        let parts = identifier.split(separator: "/")
        return parts.count > 1 ? String(parts[0]) : "Other"
    }

    static func city(of identifier: String) -> String {
        let parts = identifier.split(separator: "/")
        let tail = parts.count > 1 ? parts.dropFirst().joined(separator: " · ") : identifier
        return tail.replacingOccurrences(of: "_", with: " ")
    }

    /// "GMT+3" — shown next to the picker so a wrong pick is obvious.
    static func offsetText(for timeZone: TimeZone, at date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        return minutes == 0 ? "GMT\(sign)\(hours)" : String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }
}
