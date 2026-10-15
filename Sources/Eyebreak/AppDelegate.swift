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
    private var shiftModel: ShiftModel!
    private var activityModel: ActivityModel!
    private var unlockPrompt: UnlockPrompt!

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
    /// Last menu bar title and symbol drawn, so they're only rebuilt when they change.
    private var statusTitleKey = ""
    private var statusImageName = ""

    func applicationWillFinishLaunching(_ notification: Notification) {
        shiftModel = ShiftModel()
        // Before launch finishes: a click on the "start now" notification can be what
        // launched the app, and that response only reaches a delegate already in place.
        unlockPrompt = UnlockPrompt(shift: shiftModel)
        unlockPrompt.activate()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        timerManager = TimerManager()
        waterReminderManager = WaterReminderManager()
        ambientReminderManager = AmbientReminderManager()
        presenceMonitor = PresenceMonitor(shift: shiftModel)
        activityModel = ActivityModel(shift: shiftModel)
        timerManager.onRecord = { [weak self] taken in self?.activityModel.record(taken ? .breakTaken : .breakSkipped) }
        waterReminderManager.onRecord = { [weak self] drank in self?.activityModel.record(drank ? .drank : .waterMissed) }
        // Coming from Shift Countdown, keep its countdown in the menu bar beside EyeBreak's.
        if shiftModel.migration == .fromShiftCountdown && settings.menuBarCountdown == .nextBreak {
            settings.menuBarCountdown = .both
        }
        settingsWindowController = SettingsWindowController { [unowned self] navigation in
            SettingsView(
                navigation: navigation,
                settings: settings,
                stats: stats,
                shift: shiftModel,
                activity: activityModel,
                timerManager: timerManager,
                unlockPrompt: unlockPrompt,
                loginItemManager: loginItemManager,
                actions: SettingsActions(
                    previewBreak: { [weak self] in self?.timerManager.takeBreakNow(isPreview: true) },
                    showWaterNow: { [weak self] in self?.showWaterReminderNow() },
                    showAmbientNow: { [weak self] in self?.showAmbientReminderNow() },
                    resetHistory: { [weak self] in
                        self?.stats.reset()
                        self?.activityModel.reset()
                    }
                )
            )
        }

        setupStatusItem()
        setupBreaks()
        setupReminders()
        setupPresence()
        setupHotkeys()
        unlockPrompt.onOpenSettings = { [weak self] in self?.settingsWindowController.show(pane: .workday) }

        presenceMonitor.start()
        unlockPrompt.start()
        if settings.autoStartTimer {
            timerManager.start()
        }
        waterReminderManager.start()
        ambientReminderManager.start()

        if !settings.hasLaunchedBefore {
            settingsWindowController.show(pane: .breaks)
        }

        #if DEBUG
        // For checking UI without clicking through it: launch with `-openSettingsPane Shift`
        // (any pane name), `-openMenu YES`, `-previewShiftPrompt YES` or `-appearance dark`.
        if let appearance = UserDefaults.standard.string(forKey: "appearance") {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        if let name = UserDefaults.standard.string(forKey: "openSettingsPane"), let pane = SettingsPane(rawValue: name) {
            settingsWindowController.show(pane: pane)
        }
        if UserDefaults.standard.bool(forKey: "openMenu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.togglePopover() }
        }
        if UserDefaults.standard.bool(forKey: "previewShiftPrompt") {
            unlockPrompt.previewToast()
        }
        // `-previewBreak YES` (with `-previewLong YES`, `-previewElapsed 22`, `-breakStyle "Floating Window"`)
        if UserDefaults.standard.bool(forKey: "previewBreak") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.timerManager.debugPreview(long: UserDefaults.standard.bool(forKey: "previewLong"),
                                                elapsed: UserDefaults.standard.double(forKey: "previewElapsed"))
            }
        }
        if UserDefaults.standard.bool(forKey: "previewWater") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.waterReminderManager.triggerNow() }
        }
        #endif
    }

    // MARK: - Links
    /// `eyebreak://statistics` and `eyebreak://shift`, from the widgets.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "eyebreak" else { return }
        let pane: SettingsPane? = switch url.host {
        case "statistics", "breaks": .breaks
        case "water": .water
        case "shift", "workday": .workday
        default: nil
        }
        settingsWindowController.show(pane: pane)
    }

    /// The app menu's Settings… while the window is open (and the app has a menu bar).
    func showSettings() {
        popover.performClose(nil)
        settingsWindowController.show()
    }

    // MARK: - Status Item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeBreak")
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked)
            button.target = self
            // Right-click (or control-click) for the quick menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menuBarView = MenuBarView(
            timerManager: timerManager,
            waterManager: waterReminderManager,
            ambientManager: ambientReminderManager,
            shift: shiftModel,
            activity: activityModel,
            settings: settings,
            actions: MenuActions(
                takeBreak: { [weak self] in self?.takeBreakNow() },
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
        shiftModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateStatusItem() }
            .store(in: &cancellables)
        settings.$menuBarCountdown
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let dimmed = !timerManager.isOnBreak && (!timerManager.isRunning || timerManager.pauseReason != nil)
        // The heads-up: the eye fills for the last minute before a break, and while one waits
        // for a pause in typing. No toast, no sound.
        let breakSoon = !dimmed && !timerManager.isOnBreak
            && (timerManager.isWaitingForPause || timerManager.isInWarningPeriod || timerManager.timeRemaining <= 60)
        let imageName = dimmed ? "eye.slash" : breakSoon ? "eye.fill" : "eye"
        if statusImageName != imageName {
            statusImageName = imageName
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "EyeBreak")
        }

        // Countdowns beside the icon: the next break (or what's left of this one), and the
        // shift. The break's is hidden while paused, where a frozen number would mislead.
        let choice = settings.menuBarCountdown
        let breakCountdown: TimeInterval? = !choice.showsBreak || dimmed ? nil
            : timerManager.isOnBreak ? timerManager.breakTimeRemaining
            : timerManager.timeRemaining
        let shiftStatus = shiftModel.status
        let shiftText = choice.showsShift ? ShiftText.short(for: shiftStatus, now: shiftModel.now) : nil
        let shiftSymbol = ShiftText.symbol(for: shiftStatus)

        let key = "\(breakCountdown.map(Self.menuBarTime) ?? "")|\(shiftText ?? "")|\(shiftSymbol)"
        if key != statusTitleKey {
            statusTitleKey = key
            button.attributedTitle = Self.statusTitle(
                breakTime: breakCountdown.map(Self.menuBarTime),
                shift: shiftText.map { (shiftSymbol, $0) }
            )
        }

        var spoken = ["EyeBreak"]
        if let reason = timerManager.pauseReason {
            spoken.append(reason == .user
                ? String(localized: "All reminders paused \(PauseDuration.phrase(for: timerManager.pausedUntil))")
                : reason.label)
        } else if let breakCountdown {
            spoken.append(timerManager.isOnBreak
                ? String(localized: "\(Self.menuBarTime(breakCountdown)) until the break ends")
                : String(localized: "\(Self.menuBarTime(breakCountdown)) until your next break"))
        }
        if let shiftText {
            spoken.append("\(shiftText) \(ShiftText.accessibilityPhrase(for: shiftStatus))")
        }
        button.setAccessibilityLabel(spoken.joined(separator: ", "))

        let breakTip: String
        if !timerManager.isRunning {
            breakTip = String(localized: "EyeBreak: click to start")
        } else if timerManager.isOnBreak {
            breakTip = String(localized: "Break: \(TimerManager.format(timerManager.breakTimeRemaining)) left")
        } else if let reason = timerManager.pauseReason {
            breakTip = reason == .user ? String(localized: "All reminders paused \(PauseDuration.phrase(for: timerManager.pausedUntil))") : reason.label
        } else if timerManager.isWaitingForPause {
            breakTip = timerManager.isInCall ? String(localized: "Break after your call") : String(localized: "Break when you pause typing")
        } else {
            breakTip = String(localized: "Next break in \(timerManager.formattedTimeRemaining)")
        }
        let shiftTip = "\(ShiftText.headline(for: shiftStatus)) \(ShiftText.long(until: shiftStatus?.target, from: shiftModel.now))"
        button.toolTip = "\(breakTip)\n\(shiftTip)"
    }

    /// " 14:32", " ⌛ 3:24", or both, in tabular digits so the item doesn't shift width
    /// every second. The shift's state symbol is a template image, drawn in the menu bar's
    /// own text colour.
    private static func statusTitle(breakTime: String?, shift: (symbol: String, text: String)?) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .baselineOffset: 0.5]
        let title = NSMutableAttributedString()
        if let breakTime {
            title.append(NSAttributedString(string: " " + breakTime, attributes: attributes))
        }
        if let shift {
            title.append(NSAttributedString(string: breakTime == nil ? " " : "   ", attributes: attributes))
            let configuration = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize - 1, weight: .regular)
            if let image = NSImage(systemSymbolName: shift.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) {
                image.isTemplate = true
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2,
                                           width: image.size.width, height: image.size.height)
                title.append(NSAttributedString(attachment: attachment))
            }
            title.append(NSAttributedString(string: " " + shift.text, attributes: attributes))
        }
        return title
    }

    /// "14:32", "0:45" — no leading zero on minutes, as in the system clock.
    private static func menuBarTime(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60).localizedDigits
    }

    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showQuickMenu()
        } else {
            togglePopover()
        }
    }

    /// The right-click menu: pause or resume everything without opening the popover.
    private func showQuickMenu() {
        popover.performClose(nil)
        let menu = NSMenu()
        if timerManager.isPaused {
            let state = NSMenuItem(title: String(localized: "Paused \(PauseDuration.phrase(for: timerManager.pausedUntil))"), action: nil, keyEquivalent: "")
            state.isEnabled = false
            menu.addItem(state)
            menu.addItem(ClosureMenuItem(title: String(localized: "Resume Reminders")) { [weak self] in self?.timerManager.resume() })
        } else {
            menu.addItem(NSMenuItem.sectionHeader(title: String(localized: "Pause All Reminders")))
            for duration in PauseDuration.allCases {
                menu.addItem(ClosureMenuItem(title: duration.title) { [weak self] in
                    self?.timerManager.pause(until: duration.until())
                })
            }
        }
        menu.addItem(.separator())
        if timerManager.canPostpone && (timerManager.isInWarningPeriod || timerManager.isWaitingForPause) {
            menu.addItem(ClosureMenuItem(title: String(localized: "5 More Minutes")) { [weak self] in self?.timerManager.postpone() })
        }
        menu.addItem(ClosureMenuItem(title: String(localized: "Take a Break Now")) { [weak self] in self?.takeBreakNow() })
        if settings.waterReminderEnabled {
            menu.addItem(ClosureMenuItem(title: String(localized: "I Drank a Glass of Water")) { [weak self] in self?.waterReminderManager.drink() })
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: String(localized: "Settings…"), keyEquivalent: ",") { [weak self] in self?.showSettings() })
        menu.addItem(ClosureMenuItem(title: String(localized: "Quit EyeBreak"), keyEquivalent: "q") { NSApp.terminate(nil) })

        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
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

        warningWindowController.onSkip = { [weak self] in
            self?.timerManager.skipBreak()
        }

        floatingBreakController.onSkip = { [weak self] in
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
        let water = waterPromptForBreak()
        switch timerManager.currentBreakStyle {
        case .blurScreen, .eyeExercise:
            breakOverlay.show(palette: palette) { BlockerView(timerManager: timerManager, water: water) }
        case .floatingWindow:
            floatingBreakController.show(timerManager: timerManager, water: water)
        case .notificationOnly:
            NotificationManager.postBreakStart(duration: timerManager.currentBreakDuration, isLong: timerManager.isLongBreak)
        }
    }

    /// The long break carries the water reminder: one interruption, and you're up anyway.
    private func waterPromptForBreak() -> BreakWaterPrompt? {
        guard settings.waterReminderEnabled, settings.waterRidesWithBreaks else { return nil }
        return BreakWaterPrompt(glass: WaterAmount.text(settings.glassSizeML, unit: settings.waterUnit)) { [weak self] in
            self?.waterReminderManager.drink()
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
            message: String(localized: "Breaks pause outside your shift, and you're off shift now."),
            question: String(localized: "Would you like to take a break anyway or adjust your schedule?"),
            confirmTitle: String(localized: "Take Break Anyway")
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

        // Show the water reminder only while it's due and no break, break warning or call needs
        // the screen; it reappears once they're over. @Published fires on willSet, so hop to
        // the next main-queue turn before reading the window state.
        Publishers.CombineLatest4(
            waterReminderManager.$isDue,
            timerManager.$isOnBreak,
            timerManager.$isInWarningPeriod,
            timerManager.$isInCall
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isDue, isOnBreak, isInWarningPeriod, isInCall in
            guard let self = self else { return }
            let shouldShow = isDue && !isOnBreak && !isInWarningPeriod && !isInCall
            if shouldShow && !self.waterReminderWindowController.isVisible {
                self.waterReminderWindowController.showReminder(waterManager: self.waterReminderManager)
            } else if !shouldShow {
                self.waterReminderWindowController.hideReminder()
            }
        }
        .store(in: &cancellables)

        ambientReminderManager.onFire = { [weak self] reminder in
            guard let self = self, !self.timerManager.isOnBreak, !self.timerManager.isInWarningPeriod,
                  !self.timerManager.isInCall else { return }
            self.ambientReminderWindowController.show(reminder, duration: TimeInterval(self.settings.ambientReminderDurationSeconds))
        }
    }

    private func showWaterReminderNow() {
        popover.performClose(nil)
        guard confirmOutsideSchedule(
            message: String(localized: "Reminders pause outside your shift, and you're off shift now."),
            question: String(localized: "Would you like to show a reminder anyway?"),
            confirmTitle: String(localized: "Show Anyway")
        ) else { return }
        waterReminderManager.triggerNow()
    }

    private func showAmbientReminderNow() {
        popover.performClose(nil)
        guard confirmOutsideSchedule(
            message: String(localized: "Reminders pause outside your shift, and you're off shift now."),
            question: String(localized: "Would you like to show a reminder anyway?"),
            confirmTitle: String(localized: "Show Anyway")
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

        // Breaks and reminders hold while a camera or the microphone is in use
        presenceMonitor.$isInCall
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inCall in self?.timerManager.setInCall(inCall) }
            .store(in: &cancellables)

        // A night shift stays one day in the history too
        shiftModel.$schedule
            .sink { [weak self] schedule in self?.stats.dayStartMinutes = schedule.dayStartMinutes }
            .store(in: &cancellables)

        // Schedule or idle settings changed: re-check right away instead of on the next poll
        settings.objectWillChange
            .merge(with: shiftModel.$schedule.dropFirst().map { _ in })
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.presenceMonitor.evaluate() }
            .store(in: &cancellables)
    }

    /// "Off Shift" prompt for manual actions. Returns true to go ahead.
    private func confirmOutsideSchedule(message: String, question: String, confirmTitle: String) -> Bool {
        guard settings.smartScheduleEnabled, !presenceMonitor.isWithinSchedule else { return true }

        let alert = NSAlert()
        alert.messageText = String(localized: "Off Shift")
        alert.informativeText = [message, String(localized: "Your shift: \(shiftModel.schedule.summaryText())"), "", question]
            .joined(separator: "\n")
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: String(localized: "Adjust Shift"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertSecondButtonReturn:
            settingsWindowController.show(pane: .workday)
            return false
        default:
            return false
        }
    }

    // MARK: - Hotkeys
    private func setupHotkeys() {
        // ⌥⇧⎋ skips a break from anywhere: one on screen, one about to start, or one waiting
        hotkeyManager.onOverride = { [weak self] in
            guard let self = self else { return }
            let timer = self.timerManager!
            guard timer.isOnBreak || timer.isInWarningPeriod || timer.isWaitingForPause else { return }
            timer.skipBreak()
        }

        // Plain ESC while our break or water window has focus: skip the break, or "not now"
        // for water. The same key means the same thing everywhere.
        hotkeyManager.onEscape = { [weak self] in
            guard let self = self else { return false }
            if self.timerManager.isOnBreak && self.timerManager.currentBreakStyle != .notificationOnly {
                self.timerManager.skipBreak()
                return true
            }
            if self.waterReminderWindowController.isVisible {
                self.waterReminderManager.decline()
                return true
            }
            return false
        }

        hotkeyManager.startMonitoring()
    }
}

/// A menu item that runs a closure, for menus built in code.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() { handler() }
}
