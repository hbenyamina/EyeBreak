import Foundation

// MARK: - Options
// Raw values match EyeBreak 2.2.0's stored strings so existing preferences keep working.

enum BreakStyle: String, CaseIterable, Identifiable {
    case blurScreen = "Blur Screen"
    case floatingWindow = "Floating Window"
    /// 2.2.0's follow-the-dot exercise. Every break now guides your eyes, so a stored
    /// "Eye Exercise" reads as the full screen.
    case eyeExercise = "Eye Exercise"
    case notificationOnly = "Notification Only"

    var id: String { rawValue }

    /// What Settings offers.
    static let choices: [BreakStyle] = [.blurScreen, .floatingWindow, .notificationOnly]

    var label: String {
        switch self {
        case .blurScreen, .eyeExercise: return String(localized: "Full Screen")
        case .floatingWindow: return String(localized: "Window")
        case .notificationOnly: return String(localized: "Notification")
        }
    }

    var detail: String {
        switch self {
        case .blurScreen, .eyeExercise: return String(localized: "The screen frosts over, so there's nothing to read but the next step.")
        case .floatingWindow: return String(localized: "A small window at the top of the screen. A break you type through doesn't count.")
        case .notificationOnly: return String(localized: "Just a notification. A break you type through doesn't count.")
        }
    }

    /// Breaks you can keep working through, so whether you rested is read from your input.
    var isNonBlocking: Bool { self == .floatingWindow || self == .notificationOnly }
}

enum WaterReminderStyle: String, CaseIterable, Identifiable {
    case blurScreen = "Blur Screen"
    case floatingWindow = "Floating Window"

    var id: String { rawValue }
    var label: String { self == .blurScreen ? String(localized: "Full Screen") : String(localized: "Window") }

    var detail: String {
        switch self {
        case .blurScreen: return String(localized: "The whole screen frosts over until you answer.")
        case .floatingWindow: return String(localized: "A small window at the top of the screen.")
        }
    }
}

/// When EyeBreak asks you to drink.
enum WaterReminderMode: String, CaseIterable, Identifiable {
    /// The long break asks you to refill: one interruption instead of two.
    case withBreaks
    case ownTimer

    var id: String { rawValue }

    var label: String { self == .withBreaks ? String(localized: "With the Long Break") : String(localized: "On Its Own Timer") }

    var detail: String {
        switch self {
        case .withBreaks: return String(localized: "The long break asks you to refill, so there's no separate reminder.")
        case .ownTimer: return String(localized: "A reminder of its own, between breaks.")
        }
    }
}

enum TimingPreset: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case classic = "20-20-20"
    case custom = "Custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: return String(localized: "Recommended")
        case .classic: return String(localized: "20-20-20")
        case .custom: return String(localized: "Custom")
        }
    }

    /// Work minutes, break seconds, a long break after every Nth (0 = none) and its
    /// minutes; nil for custom.
    var values: (work: Int, breakSeconds: Int, longBreakEvery: Int, longMinutes: Int)? {
        switch self {
        case .recommended: return (20, 30, 3, 5)
        case .classic: return (20, 20, 0, 5)
        case .custom: return nil
        }
    }

    var detail: String {
        switch self {
        case .recommended: return String(localized: "Every 20 minutes, 30 seconds to look away and blink. Every hour, 5 minutes on your feet.")
        case .classic: return String(localized: "Every 20 minutes, 20 seconds looking 20 feet away.")
        case .custom: return String(localized: "Your own lengths, set under More options.")
        }
    }
}

/// Common shift hours, offered as a starting point in Settings → Workday.
enum SchedulePreset: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case flexible = "Flexible"
    case earlyBird = "Early Bird"
    case nightOwl = "Night Owl"

    var id: String { rawValue }

    var hours: (start: Int, end: Int) {
        switch self {
        case .standard: return (9, 17)
        case .flexible: return (8, 18)
        case .earlyBird: return (6, 14)
        case .nightOwl: return (14, 22)
        }
    }

    var name: String {
        switch self {
        case .standard: return String(localized: "Standard")
        case .flexible: return String(localized: "Flexible")
        case .earlyBird: return String(localized: "Early Bird")
        case .nightOwl: return String(localized: "Night Owl")
        }
    }

    var label: String {
        "\(name) (\(ShiftSchedule.timeText(hour: hours.start, minute: 0)) – \(ShiftSchedule.timeText(hour: hours.end, minute: 0)))"
    }
}

/// What sits next to the eye in the menu bar.
enum MenuBarCountdown: String, CaseIterable, Identifiable {
    case nextBreak = "Next Break"
    case shift = "End of Shift"
    case both = "Both"
    case none = "Icon Only"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nextBreak: return String(localized: "Next Break")
        case .shift: return String(localized: "End of Shift")
        case .both: return String(localized: "Both")
        case .none: return String(localized: "Icon Only")
        }
    }

    var showsBreak: Bool { self == .nextBreak || self == .both }
    var showsShift: Bool { self == .shift || self == .both }
}

// MARK: - Settings Store
/// UserDefaults-backed settings. First-launch defaults come from `config.json`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key: String {
        case workIntervalMinutes, breakDurationSeconds, preBreakWarningSeconds, autoStartTimer
        case longBreakEvery, longBreakMinutes
        case soundEffectsEnabled, breakStyle
        case skipsBeforeDryEyeNudge, dailyBreakGoal, breakGoalFollowsShift
        case waitForPause, holdDuringCalls
        case pomodoroFocusMinutes, pomodoroBreakMinutes, pomodoroLongBreakMinutes, pomodoroLongBreakEvery, pomodoroAutoContinue
        case waterGoalML, glassSizeML, waterUnit, bodyWeightKg, activeMinutesPerDay, hotClimate
        case waterSex, exerciseIntensity, waterReminderMode
        case appTheme
        case smartScheduleEnabled, askOnUnlock
        case idleDetectionEnabled, idleThresholdMinutes
        case waterReminderEnabled, waterReminderInterval, waterReminderStyle
        case useCustomWaterReminder, customWaterReminderIcon, customWaterReminderMessage
        case ambientRemindersEnabled, ambientReminderIntervalMinutes, ambientReminderDurationSeconds
        case hasLaunchedBefore, showMenuBarCountdown, menuBarCountdown
        /// Which version of the break model the stored settings were moved onto.
        case rhythmModel
    }

    private let defaults = UserDefaults.standard

    // MARK: Breaks
    @Published var workIntervalMinutes: Int { didSet { set(workIntervalMinutes, .workIntervalMinutes) } }
    @Published var breakDurationSeconds: Int { didSet { set(breakDurationSeconds, .breakDurationSeconds) } }
    /// Every Nth break is a long one; 0 turns long breaks off.
    @Published var longBreakEvery: Int { didSet { set(longBreakEvery, .longBreakEvery) } }
    @Published var longBreakMinutes: Int { didSet { set(longBreakMinutes, .longBreakMinutes) } }
    /// The heads-up toast before a break; 0 leaves it to the menu bar.
    @Published var preBreakWarningSeconds: Int { didSet { set(preBreakWarningSeconds, .preBreakWarningSeconds) } }
    @Published var autoStartTimer: Bool { didSet { set(autoStartTimer, .autoStartTimer) } }
    @Published var soundEffectsEnabled: Bool { didSet { set(soundEffectsEnabled, .soundEffectsEnabled) } }
    @Published var breakStyle: BreakStyle { didSet { set(breakStyle.rawValue, .breakStyle) } }
    /// Skipped breaks in a row before the next break says why it matters. Not in Settings.
    @Published var skipsBeforeDryEyeNudge: Int { didSet { set(skipsBeforeDryEyeNudge, .skipsBeforeDryEyeNudge) } }
    /// The goal when it doesn't follow the shift.
    @Published var dailyBreakGoal: Int { didSet { set(dailyBreakGoal, .dailyBreakGoal) } }
    @Published var breakGoalFollowsShift: Bool { didSet { set(breakGoalFollowsShift, .breakGoalFollowsShift) } }
    /// A break due mid-sentence waits for a pause in typing, up to two minutes.
    @Published var waitForPause: Bool { didSet { set(waitForPause, .waitForPause) } }
    /// Breaks and reminders hold while the camera or microphone is in use.
    @Published var holdDuringCalls: Bool { didSet { set(holdDuringCalls, .holdDuringCalls) } }

    // MARK: Pomodoro
    // Its own lengths: while one runs, these replace the break rhythm above.
    @Published var pomodoroFocusMinutes: Int { didSet { set(pomodoroFocusMinutes, .pomodoroFocusMinutes) } }
    @Published var pomodoroBreakMinutes: Int { didSet { set(pomodoroBreakMinutes, .pomodoroBreakMinutes) } }
    @Published var pomodoroLongBreakMinutes: Int { didSet { set(pomodoroLongBreakMinutes, .pomodoroLongBreakMinutes) } }
    /// The break after every Nth block is the long one.
    @Published var pomodoroLongBreakEvery: Int { didSet { set(pomodoroLongBreakEvery, .pomodoroLongBreakEvery) } }
    /// The next block starts as its break ends; off, it waits for Start.
    @Published var pomodoroAutoContinue: Bool { didSet { set(pomodoroAutoContinue, .pomodoroAutoContinue) } }

    // MARK: Shift
    // The hours themselves live in `ShiftModel`, in the file the widget reads.
    /// Pause breaks and reminders outside the shift. 2.2.0's "Smart Schedule" key.
    @Published var smartScheduleEnabled: Bool { didSet { set(smartScheduleEnabled, .smartScheduleEnabled) } }
    /// Ask "Start your shift from now?" on the first unlock while a shift is due.
    @Published var askOnUnlock: Bool { didSet { set(askOnUnlock, .askOnUnlock) } }

    // MARK: Away Detection
    @Published var idleDetectionEnabled: Bool { didSet { set(idleDetectionEnabled, .idleDetectionEnabled) } }
    @Published var idleThresholdMinutes: Int { didSet { set(idleThresholdMinutes, .idleThresholdMinutes) } }

    // MARK: Water
    @Published var waterReminderEnabled: Bool { didSet { set(waterReminderEnabled, .waterReminderEnabled) } }
    @Published var waterReminderMode: WaterReminderMode { didSet { set(waterReminderMode.rawValue, .waterReminderMode) } }
    /// Daily drinking goal, in millilitres; each "I drank" adds one glass of `glassSizeML`.
    @Published var waterGoalML: Int { didSet { set(waterGoalML, .waterGoalML) } }
    @Published var glassSizeML: Int { didSet { set(glassSizeML, .glassSizeML) } }
    @Published var waterUnit: WaterUnit { didSet { set(waterUnit.rawValue, .waterUnit) } }
    // The goal calculator's answers (0 weight = not filled in yet)
    @Published var bodyWeightKg: Double { didSet { set(bodyWeightKg, .bodyWeightKg) } }
    @Published var waterSex: WaterSex { didSet { set(waterSex.rawValue, .waterSex) } }
    @Published var activeMinutesPerDay: Int { didSet { set(activeMinutesPerDay, .activeMinutesPerDay) } }
    @Published var exerciseIntensity: ExerciseIntensity { didSet { set(exerciseIntensity.rawValue, .exerciseIntensity) } }
    /// Hot weather without air conditioning.
    @Published var hotClimate: Bool { didSet { set(hotClimate, .hotClimate) } }
    @Published var waterReminderInterval: Int { didSet { set(waterReminderInterval, .waterReminderInterval) } }
    @Published var waterReminderStyle: WaterReminderStyle { didSet { set(waterReminderStyle.rawValue, .waterReminderStyle) } }
    @Published var useCustomWaterReminder: Bool { didSet { set(useCustomWaterReminder, .useCustomWaterReminder) } }
    @Published var customWaterReminderIcon: String { didSet { set(customWaterReminderIcon, .customWaterReminderIcon) } }
    @Published var customWaterReminderMessage: String { didSet { set(customWaterReminderMessage, .customWaterReminderMessage) } }

    // MARK: Blink reminders
    // 2.2.0's ambient reminders, now only blinks and far looks, off by default: every break
    // already ends with two full blinks.
    @Published var ambientRemindersEnabled: Bool { didSet { set(ambientRemindersEnabled, .ambientRemindersEnabled) } }
    @Published var ambientReminderIntervalMinutes: Int { didSet { set(ambientReminderIntervalMinutes, .ambientReminderIntervalMinutes) } }
    @Published var ambientReminderDurationSeconds: Int { didSet { set(ambientReminderDurationSeconds, .ambientReminderDurationSeconds) } }

    // MARK: Appearance
    @Published var themeTypes: [ThemeSurface: ThemeType] {
        didSet { for (surface, type) in themeTypes { defaults.set(type.rawValue, forKey: surface.typeKey) } }
    }
    @Published var customThemes: [ThemeSurface: ColorTheme] {
        didSet {
            for (surface, theme) in customThemes {
                defaults.set(try? JSONEncoder().encode(theme), forKey: surface.customThemeKey)
            }
        }
    }

    // MARK: App theme
    @Published var appTheme: AppTheme {
        didSet {
            set(appTheme.rawValue, .appTheme)
            Theme.current = appTheme
        }
    }

    // MARK: Lifecycle
    @Published var hasLaunchedBefore: Bool { didSet { set(hasLaunchedBefore, .hasLaunchedBefore) } }
    @Published var menuBarCountdown: MenuBarCountdown { didSet { set(menuBarCountdown.rawValue, .menuBarCountdown) } }

    // MARK: - Derived
    var workDuration: TimeInterval { TimeInterval(workIntervalMinutes * 60) }
    var breakDuration: TimeInterval { TimeInterval(breakDurationSeconds) }
    var longBreakDuration: TimeInterval { TimeInterval(longBreakMinutes * 60) }
    var warningTime: TimeInterval { TimeInterval(preBreakWarningSeconds) }
    var pomodoroFocusDuration: TimeInterval { TimeInterval(pomodoroFocusMinutes * 60) }
    var pomodoroBreakDuration: TimeInterval { TimeInterval(pomodoroBreakMinutes * 60) }
    var pomodoroLongBreakDuration: TimeInterval { TimeInterval(pomodoroLongBreakMinutes * 60) }

    /// Water asks inside the long break only when there is one and the break can show it
    /// (a notification-only break has no room for the "I Drank" row).
    var waterRidesWithBreaks: Bool { waterReminderMode == .withBreaks && longBreakEvery > 0 && breakStyle != .notificationOnly }

    var timingPreset: TimingPreset {
        TimingPreset.allCases.first {
            $0.values.map {
                $0.work == workIntervalMinutes && $0.breakSeconds == breakDurationSeconds && $0.longBreakEvery == longBreakEvery
                    && ($0.longBreakEvery == 0 || $0.longMinutes == longBreakMinutes)
            } ?? false
        } ?? .custom
    }

    func apply(_ preset: TimingPreset) {
        guard let values = preset.values else { return }
        workIntervalMinutes = values.work
        breakDurationSeconds = values.breakSeconds
        longBreakEvery = values.longBreakEvery
        if values.longBreakEvery > 0 {
            longBreakMinutes = values.longMinutes
        }
    }

    /// Breaks a shift of this length holds at the current rhythm.
    func scheduledBreaks(shiftMinutes: Int) -> Int {
        BreakGoal.scheduled(shiftMinutes: shiftMinutes, workMinutes: workIntervalMinutes, breakSeconds: breakDurationSeconds,
                            longEvery: longBreakEvery, longMinutes: longBreakMinutes)
    }

    /// The day's break goal: most of the breaks the shift holds, or the number set by hand.
    func breakGoal(shiftMinutes: Int) -> Int {
        guard breakGoalFollowsShift else { return dailyBreakGoal }
        return BreakGoal.fromShift(shiftMinutes: shiftMinutes, workMinutes: workIntervalMinutes, breakSeconds: breakDurationSeconds,
                                   longEvery: longBreakEvery, longMinutes: longBreakMinutes)
    }

    // MARK: - Init
    private init() {
        let config = ConfigManager.shared.config
        let recommended = TimingPreset.recommended.values ?? (20, 30, 3, 5)
        defaults.register(defaults: [
            Key.workIntervalMinutes.rawValue: config.workDurationMinutes,
            Key.breakDurationSeconds.rawValue: config.breakDurationSeconds,
            Key.preBreakWarningSeconds.rawValue: config.warningTimeSeconds,
            Key.autoStartTimer.rawValue: true,
            Key.longBreakEvery.rawValue: recommended.longBreakEvery,
            Key.longBreakMinutes.rawValue: recommended.longMinutes,
            Key.soundEffectsEnabled.rawValue: true,
            Key.breakStyle.rawValue: BreakStyle.blurScreen.rawValue,
            Key.skipsBeforeDryEyeNudge.rawValue: config.dryEyeNudgeThreshold,
            Key.dailyBreakGoal.rawValue: 15,
            Key.breakGoalFollowsShift.rawValue: true,
            Key.waitForPause.rawValue: true,
            Key.holdDuringCalls.rawValue: true,
            Key.pomodoroFocusMinutes.rawValue: 25,
            Key.pomodoroBreakMinutes.rawValue: 5,
            Key.pomodoroLongBreakMinutes.rawValue: 15,
            Key.pomodoroLongBreakEvery.rawValue: 4,
            Key.pomodoroAutoContinue.rawValue: true,
            Key.waterGoalML.rawValue: 2000,
            Key.glassSizeML.rawValue: 250,
            Key.waterUnit.rawValue: WaterUnit.regionDefault.rawValue,
            Key.bodyWeightKg.rawValue: 0.0,
            Key.waterSex.rawValue: WaterSex.unspecified.rawValue,
            Key.activeMinutesPerDay.rawValue: 0,
            Key.exerciseIntensity.rawValue: ExerciseIntensity.moderate.rawValue,
            Key.hotClimate.rawValue: false,
            Key.waterReminderMode.rawValue: WaterReminderMode.ownTimer.rawValue,
            Key.appTheme.rawValue: AppTheme.classic.rawValue,
            Key.smartScheduleEnabled.rawValue: false,
            Key.askOnUnlock.rawValue: true,
            Key.idleDetectionEnabled.rawValue: true,
            Key.idleThresholdMinutes.rawValue: 3,
            Key.waterReminderEnabled.rawValue: config.waterReminderInterval > 0,
            Key.waterReminderInterval.rawValue: max(Int(config.waterReminderInterval / 60), 1),
            Key.waterReminderStyle.rawValue: WaterReminderStyle.floatingWindow.rawValue,
            Key.useCustomWaterReminder.rawValue: false,
            Key.customWaterReminderIcon.rawValue: "drop.fill",
            Key.customWaterReminderMessage.rawValue: "Time for a glass of water",
            Key.ambientRemindersEnabled.rawValue: false,
            Key.ambientReminderIntervalMinutes.rawValue: 10,
            Key.ambientReminderDurationSeconds.rawValue: 6,
            Key.hasLaunchedBefore.rawValue: false,
        ])
        Self.moveToRhythmModel(defaults)

        workIntervalMinutes = max(defaults.integer(forKey: Key.workIntervalMinutes.rawValue), 1)
        breakDurationSeconds = max(defaults.integer(forKey: Key.breakDurationSeconds.rawValue), 5)
        preBreakWarningSeconds = max(defaults.integer(forKey: Key.preBreakWarningSeconds.rawValue), 0)
        autoStartTimer = defaults.bool(forKey: Key.autoStartTimer.rawValue)
        longBreakEvery = max(defaults.integer(forKey: Key.longBreakEvery.rawValue), 0)
        longBreakMinutes = max(defaults.integer(forKey: Key.longBreakMinutes.rawValue), 1)
        soundEffectsEnabled = defaults.bool(forKey: Key.soundEffectsEnabled.rawValue)
        let style = BreakStyle(rawValue: defaults.string(forKey: Key.breakStyle.rawValue) ?? "") ?? .blurScreen
        breakStyle = style == .eyeExercise ? .blurScreen : style
        skipsBeforeDryEyeNudge = max(defaults.integer(forKey: Key.skipsBeforeDryEyeNudge.rawValue), 1)
        dailyBreakGoal = max(defaults.integer(forKey: Key.dailyBreakGoal.rawValue), 1)
        breakGoalFollowsShift = defaults.bool(forKey: Key.breakGoalFollowsShift.rawValue)
        waitForPause = defaults.bool(forKey: Key.waitForPause.rawValue)
        holdDuringCalls = defaults.bool(forKey: Key.holdDuringCalls.rawValue)

        pomodoroFocusMinutes = max(defaults.integer(forKey: Key.pomodoroFocusMinutes.rawValue), 1)
        pomodoroBreakMinutes = max(defaults.integer(forKey: Key.pomodoroBreakMinutes.rawValue), 1)
        pomodoroLongBreakMinutes = max(defaults.integer(forKey: Key.pomodoroLongBreakMinutes.rawValue), 1)
        pomodoroLongBreakEvery = max(defaults.integer(forKey: Key.pomodoroLongBreakEvery.rawValue), 2)
        pomodoroAutoContinue = defaults.bool(forKey: Key.pomodoroAutoContinue.rawValue)

        smartScheduleEnabled = defaults.bool(forKey: Key.smartScheduleEnabled.rawValue)
        askOnUnlock = defaults.bool(forKey: Key.askOnUnlock.rawValue)

        idleDetectionEnabled = defaults.bool(forKey: Key.idleDetectionEnabled.rawValue)
        idleThresholdMinutes = max(defaults.integer(forKey: Key.idleThresholdMinutes.rawValue), 1)

        waterReminderEnabled = defaults.bool(forKey: Key.waterReminderEnabled.rawValue)
        waterReminderMode = WaterReminderMode(rawValue: defaults.string(forKey: Key.waterReminderMode.rawValue) ?? "") ?? .ownTimer
        waterGoalML = min(max(defaults.integer(forKey: Key.waterGoalML.rawValue), 250), 8000)
        let glass = min(max(defaults.integer(forKey: Key.glassSizeML.rawValue), 50), WaterGoal.largestGlass)
        glassSizeML = glass
        waterUnit = WaterUnit(rawValue: defaults.string(forKey: Key.waterUnit.rawValue) ?? "") ?? .regionDefault
        bodyWeightKg = max(defaults.double(forKey: Key.bodyWeightKg.rawValue), 0)
        waterSex = WaterSex(rawValue: defaults.string(forKey: Key.waterSex.rawValue) ?? "") ?? .unspecified
        activeMinutesPerDay = max(defaults.integer(forKey: Key.activeMinutesPerDay.rawValue), 0)
        exerciseIntensity = ExerciseIntensity(rawValue: defaults.string(forKey: Key.exerciseIntensity.rawValue) ?? "") ?? .moderate
        hotClimate = defaults.bool(forKey: Key.hotClimate.rawValue)
        // Never closer than the kidneys can keep up with for this glass
        waterReminderInterval = max(defaults.integer(forKey: Key.waterReminderInterval.rawValue), WaterGoal.minimumInterval(glass: glass))
        waterReminderStyle = WaterReminderStyle(rawValue: defaults.string(forKey: Key.waterReminderStyle.rawValue) ?? "") ?? .floatingWindow
        useCustomWaterReminder = defaults.bool(forKey: Key.useCustomWaterReminder.rawValue)
        customWaterReminderIcon = defaults.string(forKey: Key.customWaterReminderIcon.rawValue) ?? "drop.fill"
        customWaterReminderMessage = defaults.string(forKey: Key.customWaterReminderMessage.rawValue) ?? ""

        ambientRemindersEnabled = defaults.bool(forKey: Key.ambientRemindersEnabled.rawValue)
        ambientReminderIntervalMinutes = max(defaults.integer(forKey: Key.ambientReminderIntervalMinutes.rawValue), 1)
        ambientReminderDurationSeconds = max(defaults.integer(forKey: Key.ambientReminderDurationSeconds.rawValue), 2)

        var types: [ThemeSurface: ThemeType] = [:]
        var customs: [ThemeSurface: ColorTheme] = [:]
        for surface in ThemeSurface.allCases {
            types[surface] = ThemeType(rawValue: defaults.string(forKey: surface.typeKey) ?? "") ?? .standard
            customs[surface] = defaults.data(forKey: surface.customThemeKey)
                .flatMap { try? JSONDecoder().decode(ColorTheme.self, from: $0) } ?? .standard(for: surface)
        }
        themeTypes = types
        customThemes = customs

        let theme = AppTheme(rawValue: defaults.string(forKey: Key.appTheme.rawValue) ?? "") ?? .classic
        appTheme = theme
        Theme.current = theme
        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore.rawValue)
        // 3.0 had an on/off switch for the break countdown; it maps onto the first and last choices.
        let legacyCountdownOn = defaults.object(forKey: Key.showMenuBarCountdown.rawValue) as? Bool ?? true
        menuBarCountdown = defaults.string(forKey: Key.menuBarCountdown.rawValue).flatMap(MenuBarCountdown.init)
            ?? (legacyCountdownOn ? .nextBreak : .none)
    }

    /// Once, moving stored settings onto the evidence-based break model (docs/EVIDENCE.md).
    /// Only values still at the old defaults move; anything chosen by hand stays.
    private static func moveToRhythmModel(_ defaults: UserDefaults) {
        let marker = Key.rhythmModel.rawValue
        guard defaults.integer(forKey: marker) < 1 else { return }
        defer { defaults.set(1, forKey: marker) }

        // The old default, 20 seconds every 20 minutes with no long break, becomes 30 seconds
        // to look away and blink, and 5 minutes on your feet every hour.
        let isOldDefault = defaults.integer(forKey: Key.workIntervalMinutes.rawValue) == 20
            && defaults.integer(forKey: Key.breakDurationSeconds.rawValue) == 20
            && defaults.integer(forKey: Key.longBreakEvery.rawValue) == 0
        if isOldDefault, let values = TimingPreset.recommended.values {
            defaults.set(values.work, forKey: Key.workIntervalMinutes.rawValue)
            defaults.set(values.breakSeconds, forKey: Key.breakDurationSeconds.rawValue)
            defaults.set(values.longBreakEvery, forKey: Key.longBreakEvery.rawValue)
            defaults.set(values.longMinutes, forKey: Key.longBreakMinutes.rawValue)
        }
        // The 5-second toast becomes a cue in the menu bar
        if defaults.integer(forKey: Key.preBreakWarningSeconds.rawValue) == 5 {
            defaults.set(0, forKey: Key.preBreakWarningSeconds.rawValue)
        }
        // Blinking now happens inside every break, so the 10-minute nudges retire
        defaults.set(false, forKey: Key.ambientRemindersEnabled.rawValue)
        if defaults.string(forKey: Key.breakStyle.rawValue) == BreakStyle.eyeExercise.rawValue {
            defaults.set(BreakStyle.blurScreen.rawValue, forKey: Key.breakStyle.rawValue)
        }
        if defaults.integer(forKey: Key.glassSizeML.rawValue) > WaterGoal.largestGlass {
            defaults.set(WaterGoal.largestGlass, forKey: Key.glassSizeML.rawValue)
        }
    }

    private func set(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
