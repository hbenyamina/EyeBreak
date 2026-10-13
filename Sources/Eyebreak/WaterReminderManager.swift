import Foundation
import AppKit
import Combine

class WaterReminderManager: ObservableObject {
    // MARK: - Settings
    private let settings: AppSettings
    private let snoozeInterval: TimeInterval = 10 * 60

    var interval: TimeInterval { TimeInterval(settings.waterReminderInterval * 60) }
    var isEnabled: Bool { settings.waterReminderEnabled }

    // MARK: - Published Properties
    @Published private(set) var timeRemaining: TimeInterval
    /// The reminder has fired and hasn't been acknowledged yet.
    @Published private(set) var isDue = false

    // MARK: - Private Properties
    private var timer: DispatchSourceTimer?
    private var isPaused = false
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

        // Interval or on/off changes restart the countdown
        Publishers.CombineLatest(settings.$waterReminderInterval, settings.$waterReminderEnabled)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.markDrank() }
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

    /// "I already drank" / "I'll drink now" — clears the reminder and restarts the full interval.
    func markDrank() {
        isDue = false
        timeRemaining = interval
    }

    /// Dismissed without drinking — ask again a little later.
    func snooze() {
        isDue = false
        timeRemaining = min(snoozeInterval, interval)
    }

    /// "Show Water Reminder Now"
    func triggerNow() {
        isDue = true
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    // MARK: - Private Methods
    private func tick() {
        guard isEnabled, !isPaused, !isDue else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            isDue = true
        }
    }

    @objc private func handleWake() {
        // Back from sleep: start a fresh interval rather than nagging immediately
        markDrank()
    }

    // MARK: - Formatted Time String
    var formattedTimeRemaining: String {
        TimerManager.format(timeRemaining)
    }

    // MARK: - Content
    static let titles = [
        "Time for Water!", "Hydration Check", "Water Break", "Stay Hydrated",
        "Quick Reminder", "Drink Up!", "Hydration Time", "Wellness Check",
    ]

    static let messages = [
        "Stay hydrated! Take a sip of water.",
        "Don't forget to drink some water!",
        "Your body needs water. Take a quick sip!",
        "Grab a glass of water and refresh yourself.",
        "Have you had water recently? Time to hydrate!",
        "Keep your energy up with some water.",
        "A sip of water helps you stay focused!",
        "Take a moment to drink some water.",
    ]

    static let iconOptions: [(name: String, symbol: String)] = [
        ("Drop", "drop.fill"),
        ("Water Bottle", "waterbottle.fill"),
        ("Drop Circle", "drop.circle.fill"),
        ("Drop Triangle", "drop.triangle.fill"),
        ("Figure Water", "figure.water.fitness"),
        ("Cup", "cup.and.saucer.fill"),
        ("Mug", "mug.fill"),
        ("Leaf", "leaf.fill"),
        ("Heart", "heart.fill"),
        ("Sparkles", "sparkles"),
        ("Sun", "sun.max.fill"),
        ("Bell", "bell.fill"),
    ]
}
