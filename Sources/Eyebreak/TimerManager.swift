import Foundation
import AppKit
import Combine

/// Why the work timer isn't counting.
enum PauseReason: Equatable {
    case user
    case idle
    case screenLocked
    case outsideWorkHours

    var label: String {
        switch self {
        case .user: return "Paused"
        case .idle: return "Paused (You seem to be away)"
        case .screenLocked: return "Paused (Screen locked)"
        case .outsideWorkHours: return "Paused (Outside work hours)"
        }
    }

    var icon: String {
        switch self {
        case .user: return "pause.circle.fill"
        case .idle: return "moon.zzz.fill"
        case .screenLocked: return "lock.fill"
        case .outsideWorkHours: return "calendar.badge.clock"
        }
    }
}

class TimerManager: ObservableObject {
    // MARK: - Settings
    private let settings: AppSettings
    private let stats: StatsStore

    var workDuration: TimeInterval { settings.workDuration }
    var warningTime: TimeInterval { settings.warningTime }
    /// Length of the current break, or of the next one.
    var breakDuration: TimeInterval { isOnBreak ? currentBreakDuration : settings.breakDuration }

    // MARK: - Published Properties
    @Published var timeRemaining: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var autoPauseReason: PauseReason?
    @Published private(set) var isOnBreak = false
    @Published private(set) var isInWarningPeriod = false
    @Published var breakTimeRemaining: TimeInterval
    @Published private(set) var currentBreakDuration: TimeInterval
    @Published private(set) var currentBreakStyle: BreakStyle
    /// Breaks skipped in a row; reset only when a break runs to completion.
    @Published private(set) var skippedBreakStreak: Int = 0

    var pauseReason: PauseReason? { isPaused ? .user : autoPauseReason }

    /// True once the user has ignored enough breaks in a row to earn the dry-eye nudge.
    var shouldShowDryEyeNudge: Bool {
        skippedBreakStreak >= settings.skipsBeforeDryEyeNudge
    }

    // MARK: - Callbacks
    var onWarning: (() -> Void)?
    var onBreakStart: (() -> Void)?
    /// `completed` is false when the break was skipped or interrupted.
    var onBreakEnd: ((_ completed: Bool) -> Void)?
    var onStateChange: ((Bool) -> Void)?

    // MARK: - Private Properties
    private var heartbeat: DispatchSourceTimer?
    private var hasShownWarning = false
    /// Latest pause the presence monitor asked for, even if deferred until a break ends.
    private var requestedAutoPause: PauseReason?
    /// "Preview Break Style" breaks don't count toward statistics or the skip streak.
    private var isPreviewBreak = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(settings: AppSettings = .shared, stats: StatsStore = .shared) {
        self.settings = settings
        self.stats = stats
        timeRemaining = settings.workDuration
        breakTimeRemaining = settings.breakDuration
        currentBreakDuration = settings.breakDuration
        currentBreakStyle = settings.breakStyle
        setupSleepWakeNotifications()

        // A new work interval takes effect immediately (outside of a break)
        settings.$workIntervalMinutes
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isOnBreak else { return }
                self.resetWorkTimer()
            }
            .store(in: &cancellables)
    }

    deinit {
        heartbeat?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Public Methods
    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        resetWorkTimer()
        startHeartbeat()
        onStateChange?(false)
    }

    func pause() {
        guard isRunning else { return }
        isPaused = true
        onStateChange?(true)
    }

    func resume() {
        guard isRunning else { return start() }
        isPaused = false
        onStateChange?(false)
    }

    func togglePause() {
        if !isRunning || isPaused {
            resume()
        } else {
            pause()
        }
    }

    /// Idle, screen lock and Smart Schedule pauses. Coming back from being away restarts the
    /// work interval — you already rested.
    func setAutoPause(_ reason: PauseReason?) {
        requestedAutoPause = reason
        applyAutoPause()
    }

    private func applyAutoPause() {
        let reason = requestedAutoPause
        guard reason != autoPauseReason else { return }
        // Being away during a break is the point of the break; applied once it ends
        if isOnBreak && (reason == .idle || reason == .screenLocked) { return }

        let wasAway = autoPauseReason != nil
        autoPauseReason = reason
        if reason != nil {
            hasShownWarning = false
            isInWarningPeriod = false
        } else if wasAway && !isOnBreak {
            resetWorkTimer()
        }
        onStateChange?(pauseReason != nil)
    }

    func takeBreakNow(isPreview: Bool = false) {
        guard !isOnBreak else { return }
        if !isRunning {
            isRunning = true
            startHeartbeat()
        }
        startBreak(isPreview: isPreview)
    }

    func skipBreak() {
        if isOnBreak && isPreviewBreak {
            endBreak(completed: false)
            return
        }
        skippedBreakStreak += 1
        stats.recordSkipped()
        if isOnBreak {
            endBreak(completed: false)
        } else {
            resetWorkTimer()
        }
    }

    // MARK: - Heartbeat
    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in self?.tick() }
        heartbeat = timer
        timer.resume()
    }

    private func tick() {
        if isOnBreak {
            breakTimeRemaining -= 1
            if breakTimeRemaining <= 0 {
                if !isPreviewBreak {
                    skippedBreakStreak = 0
                    stats.recordCompleted(duration: currentBreakDuration)
                }
                endBreak(completed: true)
            }
            return
        }

        guard isRunning, pauseReason == nil else { return }
        timeRemaining -= 1

        if warningTime > 0 && timeRemaining <= warningTime && !hasShownWarning {
            hasShownWarning = true
            isInWarningPeriod = true
            onWarning?()
        }

        if timeRemaining <= 0 {
            startBreak()
        }
    }

    // MARK: - Phases
    private func resetWorkTimer() {
        timeRemaining = workDuration
        hasShownWarning = false
        isInWarningPeriod = false
    }

    private func startBreak(isPreview: Bool = false) {
        isPreviewBreak = isPreview
        isInWarningPeriod = false
        currentBreakStyle = settings.breakStyle
        currentBreakDuration = settings.breakDuration
        breakTimeRemaining = currentBreakDuration
        isOnBreak = true
        onBreakStart?()
    }

    private func endBreak(completed: Bool) {
        isOnBreak = false
        onBreakEnd?(completed)
        resetWorkTimer()
        applyAutoPause()
    }

    // MARK: - Sleep/Wake Handling
    private func setupSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWake() {
        // Reset timer when Mac wakes from sleep
        if isOnBreak {
            endBreak(completed: false)
        }
        resetWorkTimer()
    }

    // MARK: - Formatted Time String
    var formattedTimeRemaining: String {
        Self.format(timeRemaining)
    }

    var formattedBreakTimeRemaining: String {
        return String(format: "%d", Int(breakTimeRemaining))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
