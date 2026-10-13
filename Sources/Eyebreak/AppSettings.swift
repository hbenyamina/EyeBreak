import Foundation

// MARK: - Options
// Raw values match EyeBreak 2.2.0's stored strings so existing preferences keep working.

enum BreakStyle: String, CaseIterable, Identifiable {
    case blurScreen = "Blur Screen"
    case floatingWindow = "Floating Window"
    case eyeExercise = "Eye Exercise"
    case notificationOnly = "Notification Only"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .blurScreen: return "rectangle.inset.filled.and.person.filled"
        case .floatingWindow: return "macwindow"
        case .eyeExercise: return "eye.fill"
        case .notificationOnly: return "bell.fill"
        }
    }

    var detail: String {
        switch self {
        case .blurScreen: return "Blur your screen during breaks"
        case .floatingWindow: return "Show a small floating reminder window"
        case .eyeExercise: return "Guided eye exercise instructions"
        case .notificationOnly: return "Just a notification, nothing on screen"
        }
    }
}

enum WaterReminderStyle: String, CaseIterable, Identifiable {
    case blurScreen = "Blur Screen"
    case floatingWindow = "Floating Window"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .blurScreen: return "Full screen blur overlay with water reminder"
        case .floatingWindow: return "Gentle floating reminder window at top of screen"
        }
    }
}

enum TimingPreset: String, CaseIterable, Identifiable {
    case standard = "Default"
    case pomodoro = "Pomodoro (25/5)"
    case custom = "Custom"

    var id: String { rawValue }

    /// (work minutes, break seconds); nil for custom.
    var values: (work: Int, breakSeconds: Int)? {
        switch self {
        case .standard: return (20, 20)
        case .pomodoro: return (25, 300)
        case .custom: return nil
        }
    }

    var detail: String {
        switch self {
        case .standard: return "20-20-20 rule: every 20 minutes, 20 seconds away"
        case .pomodoro: return "Pomodoro technique: 25 minutes of work, 5 minutes break"
        case .custom: return "Customize your own work and break intervals"
        }
    }
}

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

    var label: String {
        "\(rawValue) (\(AppSettings.hourLabel(hours.start)) - \(AppSettings.hourLabel(hours.end)))"
    }
}

// MARK: - Settings Store
/// UserDefaults-backed settings. First-launch defaults come from `config.json`.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key: String {
        case workIntervalMinutes, breakDurationSeconds, preBreakWarningSeconds, autoStartTimer
        case soundEffectsEnabled, breakStyle, eyeExerciseDurationSeconds, exerciseIntervalSeconds
        case skipsBeforeDryEyeNudge, dailyBreakGoal
        case smartScheduleEnabled, workHoursStart, workHoursEnd, activeDays, pauseOnWeekends
        case idleDetectionEnabled, idleThresholdMinutes
        case waterReminderEnabled, waterReminderInterval, waterReminderStyle
        case useCustomWaterReminder, customWaterReminderIcon, customWaterReminderMessage
        case ambientRemindersEnabled, ambientReminderIntervalMinutes, ambientReminderDurationSeconds
        case useCustomReminder, customReminderEmoji, customReminderMessage
        case hasLaunchedBefore, showMenuBarCountdown
    }

    private let defaults = UserDefaults.standard

    // MARK: Breaks
    @Published var workIntervalMinutes: Int { didSet { set(workIntervalMinutes, .workIntervalMinutes) } }
    @Published var breakDurationSeconds: Int { didSet { set(breakDurationSeconds, .breakDurationSeconds) } }
    @Published var preBreakWarningSeconds: Int { didSet { set(preBreakWarningSeconds, .preBreakWarningSeconds) } }
    @Published var autoStartTimer: Bool { didSet { set(autoStartTimer, .autoStartTimer) } }
    @Published var soundEffectsEnabled: Bool { didSet { set(soundEffectsEnabled, .soundEffectsEnabled) } }
    @Published var breakStyle: BreakStyle { didSet { set(breakStyle.rawValue, .breakStyle) } }
    @Published var eyeExerciseDurationSeconds: Int { didSet { set(eyeExerciseDurationSeconds, .eyeExerciseDurationSeconds) } }
    @Published var exerciseIntervalSeconds: Int { didSet { set(exerciseIntervalSeconds, .exerciseIntervalSeconds) } }
    @Published var skipsBeforeDryEyeNudge: Int { didSet { set(skipsBeforeDryEyeNudge, .skipsBeforeDryEyeNudge) } }
    @Published var dailyBreakGoal: Int { didSet { set(dailyBreakGoal, .dailyBreakGoal) } }

    // MARK: Smart Schedule
    @Published var smartScheduleEnabled: Bool { didSet { set(smartScheduleEnabled, .smartScheduleEnabled) } }
    @Published var workHoursStart: Int { didSet { set(workHoursStart, .workHoursStart) } }
    @Published var workHoursEnd: Int { didSet { set(workHoursEnd, .workHoursEnd) } }
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    @Published var activeDays: Set<Int> {
        didSet { defaults.set(try? JSONEncoder().encode(activeDays.sorted()), forKey: Key.activeDays.rawValue) }
    }
    @Published var pauseOnWeekends: Bool { didSet { set(pauseOnWeekends, .pauseOnWeekends) } }

    // MARK: Away Detection
    @Published var idleDetectionEnabled: Bool { didSet { set(idleDetectionEnabled, .idleDetectionEnabled) } }
    @Published var idleThresholdMinutes: Int { didSet { set(idleThresholdMinutes, .idleThresholdMinutes) } }

    // MARK: Water
    @Published var waterReminderEnabled: Bool { didSet { set(waterReminderEnabled, .waterReminderEnabled) } }
    @Published var waterReminderInterval: Int { didSet { set(waterReminderInterval, .waterReminderInterval) } }
    @Published var waterReminderStyle: WaterReminderStyle { didSet { set(waterReminderStyle.rawValue, .waterReminderStyle) } }
    @Published var useCustomWaterReminder: Bool { didSet { set(useCustomWaterReminder, .useCustomWaterReminder) } }
    @Published var customWaterReminderIcon: String { didSet { set(customWaterReminderIcon, .customWaterReminderIcon) } }
    @Published var customWaterReminderMessage: String { didSet { set(customWaterReminderMessage, .customWaterReminderMessage) } }

    // MARK: Ambient
    @Published var ambientRemindersEnabled: Bool { didSet { set(ambientRemindersEnabled, .ambientRemindersEnabled) } }
    @Published var ambientReminderIntervalMinutes: Int { didSet { set(ambientReminderIntervalMinutes, .ambientReminderIntervalMinutes) } }
    @Published var ambientReminderDurationSeconds: Int { didSet { set(ambientReminderDurationSeconds, .ambientReminderDurationSeconds) } }
    @Published var useCustomReminder: Bool { didSet { set(useCustomReminder, .useCustomReminder) } }
    @Published var customReminderEmoji: String { didSet { set(customReminderEmoji, .customReminderEmoji) } }
    @Published var customReminderMessage: String { didSet { set(customReminderMessage, .customReminderMessage) } }

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

    // MARK: Lifecycle
    @Published var hasLaunchedBefore: Bool { didSet { set(hasLaunchedBefore, .hasLaunchedBefore) } }
    @Published var showMenuBarCountdown: Bool { didSet { set(showMenuBarCountdown, .showMenuBarCountdown) } }

    // MARK: - Derived
    var workDuration: TimeInterval { TimeInterval(workIntervalMinutes * 60) }
    var breakDuration: TimeInterval {
        TimeInterval(breakStyle == .eyeExercise ? eyeExerciseDurationSeconds : breakDurationSeconds)
    }
    var warningTime: TimeInterval { TimeInterval(preBreakWarningSeconds) }

    var timingPreset: TimingPreset {
        TimingPreset.allCases.first { $0.values.map { $0.work == workIntervalMinutes && $0.breakSeconds == breakDurationSeconds } ?? false } ?? .custom
    }

    func apply(_ preset: TimingPreset) {
        guard let values = preset.values else { return }
        workIntervalMinutes = values.work
        breakDurationSeconds = values.breakSeconds
    }

    func apply(_ preset: SchedulePreset) {
        workHoursStart = preset.hours.start
        workHoursEnd = preset.hours.end
    }

    static func hourLabel(_ hour: Int) -> String {
        let h = hour % 24
        let suffix = h < 12 ? "AM" : "PM"
        let display = h % 12 == 0 ? 12 : h % 12
        return "\(display) \(suffix)"
    }

    // MARK: - Init
    private init() {
        let config = ConfigManager.shared.config
        defaults.register(defaults: [
            Key.workIntervalMinutes.rawValue: config.workDurationMinutes,
            Key.breakDurationSeconds.rawValue: config.breakDurationSeconds,
            Key.preBreakWarningSeconds.rawValue: config.warningTimeSeconds,
            Key.autoStartTimer.rawValue: true,
            Key.soundEffectsEnabled.rawValue: true,
            Key.breakStyle.rawValue: BreakStyle.blurScreen.rawValue,
            Key.eyeExerciseDurationSeconds.rawValue: 30,
            Key.exerciseIntervalSeconds.rawValue: 3,
            Key.skipsBeforeDryEyeNudge.rawValue: config.dryEyeNudgeThreshold,
            Key.dailyBreakGoal.rawValue: 15,
            Key.smartScheduleEnabled.rawValue: false,
            Key.workHoursStart.rawValue: 9,
            Key.workHoursEnd.rawValue: 17,
            Key.pauseOnWeekends.rawValue: false,
            Key.idleDetectionEnabled.rawValue: true,
            Key.idleThresholdMinutes.rawValue: 3,
            Key.waterReminderEnabled.rawValue: config.waterReminderInterval > 0,
            Key.waterReminderInterval.rawValue: max(Int(config.waterReminderInterval / 60), 1),
            Key.waterReminderStyle.rawValue: WaterReminderStyle.floatingWindow.rawValue,
            Key.useCustomWaterReminder.rawValue: false,
            Key.customWaterReminderIcon.rawValue: "drop.fill",
            Key.customWaterReminderMessage.rawValue: "Time for a glass of water!",
            Key.ambientRemindersEnabled.rawValue: true,
            Key.ambientReminderIntervalMinutes.rawValue: 10,
            Key.ambientReminderDurationSeconds.rawValue: 6,
            Key.useCustomReminder.rawValue: false,
            Key.customReminderEmoji.rawValue: "👀",
            Key.customReminderMessage.rawValue: "Blink and look away",
            Key.hasLaunchedBefore.rawValue: false,
            Key.showMenuBarCountdown.rawValue: true,
        ])

        workIntervalMinutes = max(defaults.integer(forKey: Key.workIntervalMinutes.rawValue), 1)
        breakDurationSeconds = max(defaults.integer(forKey: Key.breakDurationSeconds.rawValue), 5)
        preBreakWarningSeconds = max(defaults.integer(forKey: Key.preBreakWarningSeconds.rawValue), 0)
        autoStartTimer = defaults.bool(forKey: Key.autoStartTimer.rawValue)
        soundEffectsEnabled = defaults.bool(forKey: Key.soundEffectsEnabled.rawValue)
        breakStyle = BreakStyle(rawValue: defaults.string(forKey: Key.breakStyle.rawValue) ?? "") ?? .blurScreen
        eyeExerciseDurationSeconds = max(defaults.integer(forKey: Key.eyeExerciseDurationSeconds.rawValue), 10)
        exerciseIntervalSeconds = max(defaults.integer(forKey: Key.exerciseIntervalSeconds.rawValue), 1)
        skipsBeforeDryEyeNudge = max(defaults.integer(forKey: Key.skipsBeforeDryEyeNudge.rawValue), 1)
        dailyBreakGoal = max(defaults.integer(forKey: Key.dailyBreakGoal.rawValue), 1)

        smartScheduleEnabled = defaults.bool(forKey: Key.smartScheduleEnabled.rawValue)
        workHoursStart = defaults.integer(forKey: Key.workHoursStart.rawValue)
        workHoursEnd = defaults.integer(forKey: Key.workHoursEnd.rawValue)
        activeDays = defaults.data(forKey: Key.activeDays.rawValue)
            .flatMap { try? JSONDecoder().decode([Int].self, from: $0) }
            .map(Set.init) ?? [2, 3, 4, 5, 6]
        pauseOnWeekends = defaults.bool(forKey: Key.pauseOnWeekends.rawValue)

        idleDetectionEnabled = defaults.bool(forKey: Key.idleDetectionEnabled.rawValue)
        idleThresholdMinutes = max(defaults.integer(forKey: Key.idleThresholdMinutes.rawValue), 1)

        waterReminderEnabled = defaults.bool(forKey: Key.waterReminderEnabled.rawValue)
        waterReminderInterval = max(defaults.integer(forKey: Key.waterReminderInterval.rawValue), 1)
        waterReminderStyle = WaterReminderStyle(rawValue: defaults.string(forKey: Key.waterReminderStyle.rawValue) ?? "") ?? .floatingWindow
        useCustomWaterReminder = defaults.bool(forKey: Key.useCustomWaterReminder.rawValue)
        customWaterReminderIcon = defaults.string(forKey: Key.customWaterReminderIcon.rawValue) ?? "drop.fill"
        customWaterReminderMessage = defaults.string(forKey: Key.customWaterReminderMessage.rawValue) ?? ""

        ambientRemindersEnabled = defaults.bool(forKey: Key.ambientRemindersEnabled.rawValue)
        ambientReminderIntervalMinutes = max(defaults.integer(forKey: Key.ambientReminderIntervalMinutes.rawValue), 1)
        ambientReminderDurationSeconds = max(defaults.integer(forKey: Key.ambientReminderDurationSeconds.rawValue), 2)
        useCustomReminder = defaults.bool(forKey: Key.useCustomReminder.rawValue)
        customReminderEmoji = defaults.string(forKey: Key.customReminderEmoji.rawValue) ?? "👀"
        customReminderMessage = defaults.string(forKey: Key.customReminderMessage.rawValue) ?? ""

        var types: [ThemeSurface: ThemeType] = [:]
        var customs: [ThemeSurface: ColorTheme] = [:]
        for surface in ThemeSurface.allCases {
            types[surface] = ThemeType(rawValue: defaults.string(forKey: surface.typeKey) ?? "") ?? .standard
            customs[surface] = defaults.data(forKey: surface.customThemeKey)
                .flatMap { try? JSONDecoder().decode(ColorTheme.self, from: $0) } ?? .standard(for: surface)
        }
        themeTypes = types
        customThemes = customs

        hasLaunchedBefore = defaults.bool(forKey: Key.hasLaunchedBefore.rawValue)
        showMenuBarCountdown = defaults.bool(forKey: Key.showMenuBarCountdown.rawValue)
    }

    private func set(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
