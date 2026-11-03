import Foundation
import Combine

/// One blink reminder, shown by the glass pill.
struct AmbientReminder: Equatable {
    let symbol: String
    let title: String
    let message: String

    /// Only what has evidence behind it: complete blinks and a far look (docs/EVIDENCE.md §1).
    static var presets: [AmbientReminder] { [
        AmbientReminder(symbol: "eye", title: String(localized: "Two slow blinks"),
                        message: String(localized: "Close, squeeze gently, open")),
        AmbientReminder(symbol: "binoculars", title: String(localized: "Look across the room"),
                        message: String(localized: "Something 3 metres away or more")),
    ] }
}

/// Optional blink reminders between breaks. They never take focus and fade on their own.
final class AmbientReminderManager: ObservableObject {
    private let settings: AppSettings

    var interval: TimeInterval { TimeInterval(settings.ambientReminderIntervalMinutes * 60) }
    var isEnabled: Bool { settings.ambientRemindersEnabled }

    @Published private(set) var timeRemaining: TimeInterval

    var onFire: ((AmbientReminder) -> Void)?

    private var timer: DispatchSourceTimer?
    private var isPaused = false
    private var lastReminder: AmbientReminder?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings = .shared) {
        self.settings = settings
        timeRemaining = TimeInterval(settings.ambientReminderIntervalMinutes * 60)

        Publishers.CombineLatest(settings.$ambientReminderIntervalMinutes, settings.$ambientRemindersEnabled)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.restart() }
            .store(in: &cancellables)
    }

    deinit {
        timer?.cancel()
    }

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    func restart() {
        timeRemaining = interval
    }

    /// "Show Reminder Now"
    func fireNow() {
        restart()
        onFire?(nextReminder())
    }

    private func tick() {
        guard isEnabled, !isPaused else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            fireNow()
        }
    }

    /// Blinks and far looks take turns.
    private func nextReminder() -> AmbientReminder {
        let presets = AmbientReminder.presets
        let pick = presets.first { $0 != lastReminder } ?? presets[0]
        lastReminder = pick
        return pick
    }

    var formattedTimeRemaining: String {
        TimerManager.format(timeRemaining)
    }
}
