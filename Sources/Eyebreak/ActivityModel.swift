import Combine
import Foundation
import WidgetKit

/// Today's rhythm: every break taken or skipped and every glass drunk or missed, kept for
/// the rhythm lines in the menu and Statistics, and written to `ActivityStore`'s file for
/// the Rhythm widget.
final class ActivityModel: ObservableObject {
    @Published private(set) var log: ActivityLog

    private let settings: AppSettings
    private let shift: ShiftModel
    private var cancellables = Set<AnyCancellable>()
    private var syncedDay = Calendar.current.startOfDay(for: Date())

    init(settings: AppSettings = .shared, shift: ShiftModel) {
        self.settings = settings
        self.shift = shift
        log = ActivityStore.load()
        syncContext()

        // Goals and the shift's span travel with the file, so the widget draws what the app does.
        // Any setting may move the break goal (it follows the shift and the rhythm), so all count.
        settings.objectWillChange
            .merge(with: shift.$schedule.map { _ in () })
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.syncContext() }
            .store(in: &cancellables)

        // Past midnight the file needs the new day's shift.
        shift.$now
            .sink { [weak self] now in
                guard let self, !Calendar.current.isDate(now, inSameDayAs: self.syncedDay) else { return }
                self.syncedDay = Calendar.current.startOfDay(for: now)
                self.syncContext(force: true)
            }
            .store(in: &cancellables)
    }

    /// A drink counts one glass of the size set in Water.
    func record(_ kind: ActivityEvent.Kind) {
        log.record(kind, amount: kind == .drank ? settings.glassSizeML : nil)
        syncContext(force: true)
    }

    /// Statistics' reset: today's lines start over with the history.
    func reset() {
        log.events = []
        syncContext(force: true)
    }

    /// Today's break goal: most of the breaks today's shift holds, or the number set by hand.
    var breakGoal: Int {
        settings.breakGoal(shiftMinutes: shiftMinutesToday)
    }

    /// Breaks today's shift holds at the current rhythm.
    var scheduledBreaks: Int {
        settings.scheduledBreaks(shiftMinutes: shiftMinutesToday)
    }

    /// Today's shift (late start included), or the usual length on a day off.
    private var shiftMinutesToday: Int {
        todayShiftWindow().map { Int($0.end.timeIntervalSince($0.start) / 60) } ?? shift.schedule.durationMinutes
    }

    // MARK: - Today

    private var calendar: Calendar { .current }

    var todayEvents: [ActivityEvent] { log.events(on: Date()) }
    var waterTodayML: Int { log.waterML(on: Date()) }

    func misses(_ habit: Habit, on day: Date = Date()) -> [Date] { log.misses(habit, on: day) }

    /// The span today's lines are drawn across.
    func window(on day: Date = Date()) -> DateInterval { log.window(on: day) }

    /// Oldest first: each of the last `days` days' score for a habit.
    func weekScores(_ habit: Habit, days: Int = 7) -> [Double?] { log.weekScores(habit, endingOn: Date(), days: days) }

    // MARK: - Sharing

    /// Refreshes the goals and today's shift in the file. Writes only on a change, or when
    /// an event was just recorded.
    private func syncContext(force: Bool = false) {
        var updated = log
        updated.breakGoal = breakGoal
        updated.waterGoalML = settings.waterGoalML
        updated.glassML = settings.glassSizeML
        updated.dayStartMinutes = shift.schedule.dayStartMinutes
        updated.language = L10n.appLanguage
        updated.waterUnit = settings.waterUnit
        updated.appTheme = settings.appTheme
        let window = todayShiftWindow()
        updated.shiftStart = window?.start
        updated.shiftEnd = window?.end
        guard force || updated != log else { return }
        log = updated
        ActivityStore.save(log)
        WidgetCenter.shared.reloadTimelines(ofKind: "RhythmWidget")
    }

    /// The shift that starts today (late start included), if any.
    private func todayShiftWindow() -> ShiftWindow? {
        let now = Date()
        return shift.schedule.windows(around: now, days: -1...1).first {
            calendar.isDate($0.start, inSameDayAs: now) || $0.contains(now)
        }
    }
}
