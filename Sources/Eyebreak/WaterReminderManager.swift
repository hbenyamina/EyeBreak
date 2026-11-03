import Foundation
import AppKit
import Combine

class WaterReminderManager: ObservableObject {
    // MARK: - Settings
    private let settings: AppSettings
    private let snoozeInterval: TimeInterval = 10 * 60

    var interval: TimeInterval { TimeInterval(settings.waterReminderInterval * 60) }
    var isEnabled: Bool { settings.waterReminderEnabled }
    /// The long break asks instead (every break during a Pomodoro), so there's no countdown of its own.
    var ridesWithBreaks: Bool {
        settings.waterRidesWithBreaks || (ridesWithPomodoro && settings.breakStyle != .notificationOnly)
    }

    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval
    /// The reminder has fired and hasn't been acknowledged yet.
    @Published private(set) var isDue = false
    /// A Pomodoro's block is running: its breaks ask for water instead.
    @Published var ridesWithPomodoro = false

    /// A glass drunk (true) or a reminder turned down (false), for the day's rhythm.
    var onRecord: ((_ drank: Bool) -> Void)?

    // MARK: - Private Properties
    private var timer: DispatchSourceTimer?
    private var isPaused = false
    /// Shown by hand ("Show Water Reminder Now"): putting it off isn't a missed glass.
    private var isManual = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(settings: AppSettings = .shared) {
        self.settings = settings
        timeRemaining = TimeInterval(settings.waterReminderInterval * 60)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Interval, mode or on/off changes restart the countdown
        Publishers.CombineLatest3(settings.$waterReminderInterval, settings.$waterReminderEnabled, settings.$waterReminderMode)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in self?.restart() }
            .store(in: &cancellables)
    }

    deinit {
        timer?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Public Methods
    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    /// "I drank", from anywhere: a glass toward today's goal, and the full interval starts
    /// again, so a reminder only comes when nothing's been drunk for a while.
    func drink() {
        onRecord?(true)
        restart()
    }

    /// Clears the reminder and starts a full interval, without counting a glass.
    func restart() {
        isDue = false
        isManual = false
        timeRemaining = interval
    }

    /// "Remind me in 10 minutes": not now, but soon. Not a miss — you're asked again shortly.
    func snooze() {
        isDue = false
        isManual = false
        timeRemaining = min(snoozeInterval, interval)
    }

    /// Escape: not drinking this time. Recorded, and the next reminder is a full interval
    /// away rather than a snooze; the line only dips once you're a glass behind your pace.
    func decline() {
        if isDue && !isManual { onRecord?(false) }
        restart()
    }

    /// "Show Water Reminder Now"
    func triggerNow() {
        isManual = !isDue
        isDue = true
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    // MARK: - Private Methods
    private func tick() {
        guard isEnabled, !ridesWithBreaks, !isPaused, !isDue else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            isDue = true
        }
    }

    @objc private func handleWake() {
        // Back from sleep: start a fresh interval rather than nagging immediately
        restart()
    }

    // MARK: - Formatted Time String
    var formattedTimeRemaining: String {
        TimerManager.format(timeRemaining)
    }

    // MARK: - Content
    static var titles: [String] { [
        String(localized: "Time for some water"),
        String(localized: "A glass of water"),
        String(localized: "Water, when you're ready"),
    ] }

    static var messages: [String] { [
        String(localized: "A glass now keeps you on pace for the day."),
        String(localized: "Water, tea or coffee all count."),
        String(localized: "Fill a glass and take it back to your desk."),
        String(localized: "A few sips now, before you get thirsty."),
    ] }

    static var iconOptions: [(name: String, symbol: String)] { [
        (String(localized: "Drop"), "drop.fill"),
        (String(localized: "Water Bottle"), "waterbottle.fill"),
        (String(localized: "Drop Circle"), "drop.circle.fill"),
        (String(localized: "Drop Triangle"), "drop.triangle.fill"),
        (String(localized: "Figure Water"), "figure.water.fitness"),
        (String(localized: "Cup"), "cup.and.saucer.fill"),
        (String(localized: "Mug"), "mug.fill"),
        (String(localized: "Leaf"), "leaf.fill"),
        (String(localized: "Heart"), "heart.fill"),
        (String(localized: "Sparkles"), "sparkles"),
        (String(localized: "Sun"), "sun.max.fill"),
        (String(localized: "Bell"), "bell.fill"),
    ] }
}
