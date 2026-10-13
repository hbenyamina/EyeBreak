import Foundation
import Combine

/// One gentle nudge shown by the ambient reminder pill.
struct AmbientReminder: Equatable {
    enum Glyph: Equatable {
        case symbol(String)
        case emoji(String)
    }

    let glyph: Glyph
    let title: String
    let message: String

    static let presets = [
        AmbientReminder(glyph: .symbol("eye"), title: "Blink", message: "Blink slowly a few times"),
        AmbientReminder(glyph: .symbol("arrow.left"), title: "Look to the left", message: "Glance away for a moment"),
        AmbientReminder(glyph: .symbol("arrow.right"), title: "Look to the right", message: "Give your focus a stretch"),
        AmbientReminder(glyph: .symbol("mountain.2"), title: "Take a visual break", message: "Find something far away"),
        AmbientReminder(glyph: .symbol("scope"), title: "Shift your focus", message: "Look past your screen"),
        AmbientReminder(glyph: .symbol("window.vertical.closed"), title: "Change your view", message: "Look out a window"),
        AmbientReminder(glyph: .symbol("eye.slash"), title: "Rest for a moment", message: "Close your eyes for a breath"),
    ]
}

/// Cute periodic reminders while you work. They never take focus and fade out on their own.
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

    private func nextReminder() -> AmbientReminder {
        if settings.useCustomReminder && !settings.customReminderMessage.isEmpty {
            return AmbientReminder(glyph: .emoji(settings.customReminderEmoji), title: settings.customReminderMessage, message: "Eye care reminder")
        }
        // Avoid repeating the same nudge twice in a row
        let pick = AmbientReminder.presets.filter { $0 != lastReminder }.randomElement() ?? AmbientReminder.presets[0]
        lastReminder = pick
        return pick
    }

    var formattedTimeRemaining: String {
        TimerManager.format(timeRemaining)
    }
}
