import AppKit
import CoreGraphics

/// Watches for the user being away (idle input, locked screen) and for Smart Schedule hours.
final class PresenceMonitor: ObservableObject {
    @Published private(set) var isIdle = false
    @Published private(set) var isScreenLocked = false
    @Published private(set) var isWithinSchedule = true

    private let settings: AppSettings
    private var timer: Timer?

    init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    deinit {
        timer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)

        evaluate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.evaluate() }
    }

    /// Re-check immediately, e.g. after schedule settings change.
    func evaluate() {
        isWithinSchedule = Self.isWithinSchedule(settings: settings)

        if settings.idleDetectionEnabled {
            let idleSeconds = Self.secondsSinceLastInput()
            let threshold = TimeInterval(settings.idleThresholdMinutes * 60)
            // Small hysteresis so a single mouse nudge doesn't flap the state
            if !isIdle && idleSeconds >= threshold {
                isIdle = true
            } else if isIdle && idleSeconds < 5 {
                isIdle = false
            }
        } else if isIdle {
            isIdle = false
        }
    }

    static func isWithinSchedule(settings: AppSettings, at date: Date = Date()) -> Bool {
        guard settings.smartScheduleEnabled else { return true }
        let calendar = Calendar.current
        if settings.pauseOnWeekends && calendar.isDateInWeekend(date) { return false }
        guard settings.activeDays.contains(calendar.component(.weekday, from: date)) else { return false }

        let hour = calendar.component(.hour, from: date)
        let start = settings.workHoursStart
        let end = settings.workHoursEnd
        if start == end { return true }
        // Overnight ranges (e.g. 22 → 6) wrap past midnight
        return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }

    private static func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged, .leftMouseDragged]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    @objc private func screenLocked() { isScreenLocked = true }
    @objc private func screenUnlocked() { isScreenLocked = false }
}
