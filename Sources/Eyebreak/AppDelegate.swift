import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - State
    private let settings = AppSettings.shared
    private let stats = StatsStore.shared
    private let loginItemManager = LoginItemManager()
    private var timerManager: TimerManager!
    private var waterReminderManager: WaterReminderManager!
    private var ambientReminderManager: AmbientReminderManager!
    private var presenceMonitor: PresenceMonitor!

    // MARK: - UI
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let warningWindowController = WarningWindowController()
    private let breakOverlay = OverlayWindowController()
    private let floatingBreakController = FloatingBreakWindowController()
    private let waterReminderWindowController = WaterReminderWindowController()
    private let ambientReminderWindowController = AmbientReminderWindowController()
    private var settingsWindowController: SettingsWindowController!
    private let hotkeyManager = HotkeyManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerManager = TimerManager()
        waterReminderManager = WaterReminderManager()
        ambientReminderManager = AmbientReminderManager()
        presenceMonitor = PresenceMonitor()
        settingsWindowController = SettingsWindowController { [unowned self] navigation in
            SettingsView(
                navigation: navigation,
                settings: settings,
                stats: stats,
                loginItemManager: loginItemManager,
                actions: SettingsActions(
                    previewBreak: { [weak self] in self?.timerManager.takeBreakNow(isPreview: true) },
                    showWaterNow: { [weak self] in self?.showWaterReminderNow() },
                    showAmbientNow: { [weak self] in self?.showAmbientReminderNow() }
                )
            )
        }

        setupStatusItem()
        setupBreaks()
        setupReminders()
        setupPresence()
        setupHotkeys()

        presenceMonitor.start()
        if settings.autoStartTimer {
            timerManager.start()
        }
        waterReminderManager.start()
        ambientReminderManager.start()

        if !settings.hasLaunchedBefore {
            settingsWindowController.show(pane: .general)
        }
    }

    // MARK: - Status Item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeBreak")
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self
        }

        let menuBarView = MenuBarView(
            timerManager: timerManager,
            waterManager: waterReminderManager,
            ambientManager: ambientReminderManager,
            settings: settings,
            stats: stats,
            actions: MenuActions(
                takeBreak: { [weak self] in self?.takeBreakNow() },
                showWater: { [weak self] in self?.showWaterReminderNow() },
                showAmbient: { [weak self] in self?.showAmbientReminderNow() },
                openSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.settingsWindowController.show()
                }
            )
        )
        let hostingController = NSHostingController(rootView: menuBarView)
        hostingController.sizingOptions = .preferredContentSize

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController

        // Icon and tooltip follow the timer (@Published fires on willSet, so hop a turn first)
        timerManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)
        settings.$showMenuBarCountdown
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let dimmed = !timerManager.isOnBreak && (!timerManager.isRunning || timerManager.pauseReason != nil)
        let imageName = dimmed ? "eye.slash" : "eye"
        if button.image?.accessibilityDescription != imageName {
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: imageName)
        }

        // Countdown beside the icon: the next break, or what's left of this one.
        // Hidden while paused, where a frozen number would mislead.
        let countdown: TimeInterval? = !settings.showMenuBarCountdown || dimmed ? nil
            : timerManager.isOnBreak ? timerManager.breakTimeRemaining
            : timerManager.timeRemaining
        let title = countdown.map { " " + Self.menuBarTime($0) } ?? ""
        if button.title != title {
            // Tabular digits so the item doesn't shift width every second
            button.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .baselineOffset: 0.5,
            ])
        }
        button.setAccessibilityLabel(countdown.map { "EyeBreak, \(Self.menuBarTime($0)) until \(timerManager.isOnBreak ? "the break ends" : "your next break")" } ?? "EyeBreak")

        if !timerManager.isRunning {
            button.toolTip = "EyeBreak - Click to start"
        } else if timerManager.isOnBreak {
            button.toolTip = "Break time remaining: \(TimerManager.format(timerManager.breakTimeRemaining))"
        } else if let reason = timerManager.pauseReason {
            button.toolTip = reason.label
        } else if timerManager.isInWarningPeriod {
            button.toolTip = "Break starting in \(TimerManager.format(timerManager.timeRemaining))"
        } else {
            button.toolTip = "Working - Break in \(timerManager.formattedTimeRemaining)"
        }
    }

    /// "14:32", "0:45" — no leading zero on minutes, as in the system clock.
    private static func menuBarTime(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Breaks
    private func setupBreaks() {
        timerManager.onWarning = { [weak self] in
            guard let self = self else { return }
            SoundManager.play(.warning)
            self.warningWindowController.showWarning(timerManager: self.timerManager)
        }

        timerManager.onBreakStart = { [weak self] in self?.presentBreak() }
        timerManager.onBreakEnd = { [weak self] completed in self?.dismissBreak(completed: completed) }

        // The warning can end without a break: skipped from the menu, or you walked away
        timerManager.$isInWarningPeriod
            .removeDuplicates()
            .filter { !$0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.warningWindowController.hideWarning() }
            .store(in: &cancellables)

        // Configure warning window callbacks
        warningWindowController.onSkip = { [weak self] in
            self?.timerManager.skipBreak()
        }

        // Dismiss just hides the warning (break will still happen)
        warningWindowController.onDismiss = { [weak self] in
            self?.warningWindowController.hideWarning()
        }

        floatingBreakController.onClose = { [weak self] in
            self?.timerManager.skipBreak()
        }

        settings.$breakStyle
            .filter { $0 == .notificationOnly }
            .sink { _ in NotificationManager.requestAuthorization() }
            .store(in: &cancellables)
    }

    private func presentBreak() {
        warningWindowController.hideWarning()
        popover.performClose(nil)
        SoundManager.play(.breakStart)

        let palette = Palette.current(for: .breakOverlay)
        switch timerManager.currentBreakStyle {
        case .blurScreen:
            breakOverlay.show(palette: palette) { BlockerView(timerManager: timerManager) }
        case .eyeExercise:
            breakOverlay.show(palette: palette) {
                EyeExerciseView(timerManager: timerManager, holdSeconds: settings.exerciseIntervalSeconds)
            }
        case .floatingWindow:
            floatingBreakController.show(timerManager: timerManager)
        case .notificationOnly:
            NotificationManager.postBreakStart(seconds: Int(timerManager.currentBreakDuration))
        }
    }

    private func dismissBreak(completed: Bool) {
        breakOverlay.hide()
        floatingBreakController.hide()
        guard completed else { return }
        SoundManager.play(.breakEnd)
        if timerManager.currentBreakStyle == .notificationOnly {
            NotificationManager.postBreakComplete()
        }
    }

    private func takeBreakNow() {
        popover.performClose(nil)
        guard confirmOutsideSchedule(
            message: "Your Smart Schedule is active and breaks are currently paused.",
            question: "Would you like to take a break anyway or adjust your schedule?",
            confirmTitle: "Take Break Anyway"
        ) else { return }
        timerManager.takeBreakNow()
    }

    // MARK: - Reminders
    private func setupReminders() {
        // Reminders pause whenever the break timer does (you, idle, lock, schedule)
        Publishers.CombineLatest(timerManager.$isPaused, timerManager.$autoPauseReason)
            .map { isPaused, reason in isPaused || reason != nil }
            .removeDuplicates()
            .sink { [weak self] paused in
                self?.waterReminderManager.setPaused(paused)
                self?.ambientReminderManager.setPaused(paused)
            }
            .store(in: &cancellables)

        // Show the water reminder only while it's due and no break or break warning needs the
        // screen; it reappears once the break is over. @Published fires on willSet, so hop to
        // the next main-queue turn before reading the window state.
        Publishers.CombineLatest3(
            waterReminderManager.$isDue,
            timerManager.$isOnBreak,
            timerManager.$isInWarningPeriod
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isDue, isOnBreak, isInWarningPeriod in
            guard let self = self else { return }
            let shouldShow = isDue && !isOnBreak && !isInWarningPeriod
            if shouldShow && !self.waterReminderWindowController.isVisible {
                self.waterReminderWindowController.showReminder(waterManager: self.waterReminderManager)
            } else if !shouldShow {
                self.waterReminderWindowController.hideReminder()
            }
        }
        .store(in: &cancellables)

        ambientReminderManager.onFire = { [weak self] reminder in
            guard let self = self, !self.timerManager.isOnBreak, !self.timerManager.isInWarningPeriod else { return }
            self.ambientReminderWindowController.show(reminder, duration: TimeInterval(self.settings.ambientReminderDurationSeconds))
        }
    }

    private func showWaterReminderNow() {
        popover.performClose(nil)
        guard confirmOutsideSchedule(
            message: "Your Smart Schedule is active and water reminders are currently paused.",
            question: "Would you like to show a reminder anyway?",
            confirmTitle: "Show Anyway"
        ) else { return }
        waterReminderManager.triggerNow()
    }

    private func showAmbientReminderNow() {
        popover.performClose(nil)
        guard confirmOutsideSchedule(
            message: "Your Smart Schedule is active and ambient reminders are currently paused.",
            question: "Would you like to show a reminder anyway?",
            confirmTitle: "Show Anyway"
        ) else { return }
        ambientReminderManager.fireNow()
    }

    // MARK: - Presence & Schedule
    private func setupPresence() {
        Publishers.CombineLatest3(presenceMonitor.$isIdle, presenceMonitor.$isScreenLocked, presenceMonitor.$isWithinSchedule)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isIdle, isLocked, isWithinSchedule in
                let reason: PauseReason? = !isWithinSchedule ? .outsideWorkHours
                    : isLocked ? .screenLocked
                    : isIdle ? .idle
                    : nil
                self?.timerManager.setAutoPause(reason)
            }
            .store(in: &cancellables)

        // Schedule or idle settings changed: re-check right away instead of on the next poll
        settings.objectWillChange
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.presenceMonitor.evaluate() }
            .store(in: &cancellables)
    }

    /// "Outside Work Hours" prompt for manual actions. Returns true to go ahead.
    private func confirmOutsideSchedule(message: String, question: String, confirmTitle: String) -> Bool {
        guard settings.smartScheduleEnabled, !presenceMonitor.isWithinSchedule else { return true }

        let alert = NSAlert()
        alert.messageText = "Outside Work Hours"
        alert.informativeText = """
        \(message)
        Work Hours: \(AppSettings.hourLabel(settings.workHoursStart)) – \(AppSettings.hourLabel(settings.workHoursEnd))

        \(question)
        """
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Adjust Schedule")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertSecondButtonReturn:
            settingsWindowController.show(pane: .schedule)
            return false
        default:
            return false
        }
    }

    // MARK: - Hotkeys
    private func setupHotkeys() {
        // ⌥⇧⎋ skips a break from anywhere
        hotkeyManager.onOverride = { [weak self] in
            guard let self = self, self.timerManager.isOnBreak else { return }
            self.timerManager.skipBreak()
        }

        // Plain ESC while our break or water window has focus
        hotkeyManager.onEscape = { [weak self] in
            guard let self = self else { return false }
            if self.timerManager.isOnBreak && self.timerManager.currentBreakStyle != .notificationOnly {
                self.timerManager.skipBreak()
                return true
            }
            if self.waterReminderWindowController.isVisible {
                self.waterReminderManager.snooze()
                return true
            }
            return false
        }

        hotkeyManager.startMonitoring()
    }
}
