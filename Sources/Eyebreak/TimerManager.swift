import Foundation
import AppKit
import Combine

/// Why the work timer isn't counting.
enum PauseReason: Equatable {
    case user
    case idle
    case screenLocked
    /// Smart Schedule: outside the shift.
    case outsideWorkHours

    var label: String {
        switch self {
        case .user: return String(localized: "Paused")
        case .idle: return String(localized: "Paused while you're away")
        case .screenLocked: return String(localized: "Paused while the screen is locked")
        case .outsideWorkHours: return String(localized: "Paused until your shift")
        }
    }

    var icon: String {
        switch self {
        case .user: return "pause.circle.fill"
        case .idle: return "moon.zzz.fill"
        case .screenLocked: return "lock.fill"
        case .outsideWorkHours: return "moon.zzz.fill"
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
    var breakDuration: TimeInterval {
        isOnBreak ? currentBreakDuration : nextBreakIsLong ? settings.longBreakDuration : settings.breakDuration
    }
    /// Whether the coming break is the long one that closes a Pomodoro round.
    var nextBreakIsLong: Bool { round.nextIsLong(every: settings.longBreakEvery) }

    // MARK: - Published Properties
    @Published var timeRemaining: TimeInterval
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    /// When a pause you chose ends by itself; nil pauses until you resume.
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var autoPauseReason: PauseReason?
    @Published private(set) var isOnBreak = false
    @Published private(set) var isInWarningPeriod = false
    @Published var breakTimeRemaining: TimeInterval
    @Published private(set) var currentBreakDuration: TimeInterval
    @Published private(set) var currentBreakStyle: BreakStyle
    /// Breaks skipped in a row; reset only when a break runs to completion.
    @Published private(set) var skippedBreakStreak: Int = 0
    /// Position in the Pomodoro round, when long breaks are on.
    @Published private(set) var round = BreakRound()
    /// The break under way is a long one.
    @Published private(set) var isLongBreak = false
    /// A break is due, held for a pause in your typing or the end of a call.
    @Published private(set) var isWaitingForPause = false
    /// The camera or microphone is in use (from `PresenceMonitor`).
    @Published private(set) var isInCall = false
    /// "5 more minutes" used on the break that's due.
    @Published private(set) var postponesUsed = 0
    /// This break opens with why it matters: several skipped in a row. Once a day at most.
    @Published private(set) var showsSkipNote = false

    var pauseReason: PauseReason? { isPaused ? .user : autoPauseReason }

    static let maxPostpones = 2
    static let postponeMinutes = 5
    /// How long a break due mid-sentence waits for you to stop typing.
    static let longestWait = 120

    var canPostpone: Bool { postponesUsed < Self.maxPostpones && !isPreviewBreak }

    /// What the break asks of you right now.
    var breakStep: BreakStep {
        BreakGuide.step(elapsed: currentBreakDuration - breakTimeRemaining, duration: currentBreakDuration, isLong: isLongBreak)
    }

    /// Until the next long break starts; nil with long breaks off.
    var timeUntilLongBreak: TimeInterval? {
        let every = settings.longBreakEvery
        guard every > 0 else { return nil }
        if isOnBreak && isLongBreak { return 0 }
        // Work intervals still to come after this one before the long break
        var intervalsLeft = every - 1 - round.position
        var time = timeRemaining
        if isOnBreak {
            intervalsLeft -= 1
            time = breakTimeRemaining + workDuration
        }
        return time + Double(max(intervalsLeft, 0)) * (workDuration + settings.breakDuration)
    }

    // MARK: - Callbacks
    var onWarning: (() -> Void)?
    var onBreakStart: (() -> Void)?
    /// `completed` is false when the break was skipped or interrupted.
    var onBreakEnd: ((_ completed: Bool) -> Void)?
    var onStateChange: ((Bool) -> Void)?
    /// A break counted toward the day: `taken` true when it ran to the end, false when skipped.
    var onRecord: ((_ taken: Bool) -> Void)?

    // MARK: - Private Properties
    private var heartbeat: DispatchSourceTimer?
    private var hasShownWarning = false
    /// Latest pause the presence monitor asked for, even if deferred until a break ends.
    private var requestedAutoPause: PauseReason?
    /// "Preview Break Style" breaks don't count toward statistics or the skip streak.
    private var isPreviewBreak = false
    /// Seconds a due break has waited for a pause in typing.
    private var waitedSeconds = 0
    /// Seconds of input during a break you could have kept working through.
    private var activeBreakSeconds = 0
    private var lastSkipNoteDay: Date?
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
        pause(until: nil)
    }

    /// Pauses breaks and, with them, every reminder. With a date, everything resumes by
    /// itself then; without one, it waits for Resume.
    func pause(until date: Date?) {
        if !isRunning {
            // Not started yet: start, so the pause has a timer to hold and Resume to undo
            isRunning = true
            resetWorkTimer()
            startHeartbeat()
        }
        if isOnBreak {
            endBreak(completed: false)
        }
        pausedUntil = date
        isPaused = true
        hasShownWarning = false
        isInWarningPeriod = false
        isWaitingForPause = false
        onStateChange?(true)
    }

    func resume() {
        guard isRunning else { return start() }
        isPaused = false
        pausedUntil = nil
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
            isWaitingForPause = false
        } else if wasAway && !isOnBreak {
            resetWorkTimer()
            round.reset()
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

    #if DEBUG
    /// A preview break shown as long, `elapsed` seconds in, for checking the screens.
    func debugPreview(long: Bool, elapsed: TimeInterval) {
        takeBreakNow(isPreview: true)
        if long {
            isLongBreak = true
            currentBreakDuration = settings.longBreakDuration
        }
        breakTimeRemaining = max(currentBreakDuration - elapsed, 1)
    }
    #endif

    func skipBreak() {
        if isOnBreak && isPreviewBreak {
            endBreak(completed: false)
            return
        }
        recordSkip()
        if isOnBreak {
            endBreak(completed: false)
        } else {
            // Skipped before it began: the work interval still counts toward the round
            round.breakEnded(wasLong: nextBreakIsLong)
            postponesUsed = 0
            resetWorkTimer()
        }
    }

    /// "5 more minutes": the same break comes back in five, and it isn't a skip. Offered
    /// twice; after that, take it or skip it.
    func postpone() {
        guard canPostpone, isOnBreak || isInWarningPeriod || isWaitingForPause else { return }
        postponesUsed += 1
        if isOnBreak {
            // Not `endBreak`: the round doesn't move on, so a long break stays long
            isOnBreak = false
            onBreakEnd?(false)
            isLongBreak = false
        }
        timeRemaining = TimeInterval(Self.postponeMinutes * 60)
        hasShownWarning = false
        isInWarningPeriod = false
        isWaitingForPause = false
        waitedSeconds = 0
        applyAutoPause()
    }

    /// Called by the presence monitor.
    func setInCall(_ inCall: Bool) {
        guard inCall != isInCall else { return }
        isInCall = inCall
    }

    private func recordSkip() {
        skippedBreakStreak += 1
        stats.recordSkipped()
        onRecord?(false)
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
        if isPaused, let until = pausedUntil, Date() >= until {
            resume()
        }
        if isOnBreak {
            if currentBreakStyle.isNonBlocking && InputActivity.secondsSinceAnyInput() < 1.5 {
                activeBreakSeconds += 1
            }
            breakTimeRemaining -= 1
            if breakTimeRemaining <= 0 {
                if !isPreviewBreak {
                    // A break you kept working through (window or notification) wasn't one
                    if Double(activeBreakSeconds) > currentBreakDuration / 2 {
                        recordSkip()
                    } else {
                        skippedBreakStreak = 0
                        stats.recordCompleted(duration: currentBreakDuration)
                        onRecord?(true)
                    }
                }
                endBreak(completed: true)
            }
            return
        }

        guard isRunning, pauseReason == nil else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        }

        let holdingForCall = isInCall && settings.holdDuringCalls
        if warningTime > 0 && timeRemaining <= warningTime && !hasShownWarning && !holdingForCall {
            hasShownWarning = true
            isInWarningPeriod = true
            onWarning?()
        }

        if timeRemaining <= 0 {
            if shouldHoldBreak(holdingForCall: holdingForCall) {
                waitedSeconds += 1
                if !isWaitingForPause { isWaitingForPause = true }
                if holdingForCall && isInWarningPeriod { isInWarningPeriod = false }
                return
            }
            startBreak()
        }
    }

    /// A due break waits through a call, and for a pause in typing up to `longestWait`
    /// seconds: the same interruption costs less at a break in the task (Bailey & Konstan 2006).
    private func shouldHoldBreak(holdingForCall: Bool) -> Bool {
        if holdingForCall { return true }
        guard settings.waitForPause, waitedSeconds < Self.longestWait else { return false }
        return InputActivity.secondsSinceTyping() < 3
    }

    // MARK: - Phases
    private func resetWorkTimer() {
        timeRemaining = workDuration
        hasShownWarning = false
        isInWarningPeriod = false
        isWaitingForPause = false
        waitedSeconds = 0
    }

    private func startBreak(isPreview: Bool = false) {
        isPreviewBreak = isPreview
        isInWarningPeriod = false
        isWaitingForPause = false
        waitedSeconds = 0
        activeBreakSeconds = 0
        isLongBreak = !isPreview && nextBreakIsLong
        currentBreakStyle = settings.breakStyle
        currentBreakDuration = isLongBreak ? settings.longBreakDuration : settings.breakDuration
        breakTimeRemaining = currentBreakDuration
        showsSkipNote = !isPreview && skipNoteIsDue()
        isOnBreak = true
        onBreakStart?()
    }

    /// Several breaks skipped in a row: say once, plainly, why this one matters.
    private func skipNoteIsDue() -> Bool {
        guard skippedBreakStreak >= settings.skipsBeforeDryEyeNudge else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        guard lastSkipNoteDay != today else { return false }
        lastSkipNoteDay = today
        return true
    }

    private func endBreak(completed: Bool) {
        isOnBreak = false
        if !isPreviewBreak {
            round.breakEnded(wasLong: isLongBreak)
            postponesUsed = 0
        }
        onBreakEnd?(completed)
        isLongBreak = false
        showsSkipNote = false
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
        round.reset()
        postponesUsed = 0
    }

    // MARK: - Formatted Time String
    var formattedTimeRemaining: String {
        Self.format(timeRemaining)
    }

    var formattedBreakTimeRemaining: String {
        String(format: "%d", Int(breakTimeRemaining)).localizedDigits
    }

    /// "19:58", "4:27", or "1:00:58" past an hour; no leading zero, as on the system clock.
    static func format(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60).localizedDigits
        }
        return String(format: "%d:%02d", total / 60, total % 60).localizedDigits
    }
}

/// How long "Pause all reminders" lasts.
enum PauseDuration: CaseIterable, Identifiable {
    case thirtyMinutes, oneHour, twoHours, untilTomorrow, untilResumed

    var id: Self { self }

    var title: String {
        switch self {
        case .thirtyMinutes: return String(localized: "For 30 Minutes")
        case .oneHour: return String(localized: "For 1 Hour")
        case .twoHours: return String(localized: "For 2 Hours")
        case .untilTomorrow: return String(localized: "Until Tomorrow")
        case .untilResumed: return String(localized: "Until I Resume")
        }
    }

    /// When the pause ends by itself; nil waits for Resume.
    func until(from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .thirtyMinutes: return now.addingTimeInterval(30 * 60)
        case .oneHour: return now.addingTimeInterval(60 * 60)
        case .twoHours: return now.addingTimeInterval(2 * 60 * 60)
        case .untilTomorrow: return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case .untilResumed: return nil
        }
    }

    /// "until 11:30 AM", "until tomorrow", "until you resume"
    static func phrase(for date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return String(localized: "until you resume") }
        if calendar.isDateInTomorrow(date) && calendar.component(.hour, from: date) == 0 { return String(localized: "until tomorrow") }
        return String(localized: "until \(date.formatted(date: .omitted, time: .shortened))")
    }
}
