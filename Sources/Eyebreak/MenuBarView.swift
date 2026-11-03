import SwiftUI

/// Actions that need the app coordinator (windows, schedule confirmation).
struct MenuActions {
    let takeBreak: () -> Void
    let openSettings: () -> Void
}

/// The menu: the day at a glance, then what you can do about it. Top to bottom: the date
/// and shift, the next break on a piece of glass, today's rhythm lines, the other
/// countdowns, and plain actions.
struct MenuBarView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var waterManager: WaterReminderManager
    @ObservedObject var ambientManager: AmbientReminderManager
    @ObservedObject var shift: ShiftModel
    @ObservedObject var activity: ActivityModel
    @ObservedObject var settings: AppSettings
    let actions: MenuActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 12)

            if let reason = timerManager.pauseReason {
                pauseLine(reason)
                    .padding(.bottom, 10)
            }

            hero

            today
                .padding(.top, 16)

            countdowns
                .padding(.top, 12)

            hairline

            VStack(spacing: 1) {
                if breakIsDue {
                    if timerManager.canPostpone {
                        MenuRow(icon: "clock.arrow.circlepath", title: "5 More Minutes") { timerManager.postpone() }
                    }
                    MenuRow(icon: "forward", title: "Skip This Break") { timerManager.skipBreak() }
                }
                MenuRow(icon: "eye", title: "Take a Break Now", action: actions.takeBreak)
                    .disabled(timerManager.isOnBreak)
                if let pomodoro = timerManager.pomodoro {
                    if pomodoro.isWaiting {
                        MenuRow(icon: "play", title: "Start Next Pomodoro") { timerManager.startPomodoro() }
                            .disabled(timerManager.isOnBreak)
                    }
                    MenuRow(icon: "stop", title: "Stop Pomodoro") { timerManager.stopPomodoro() }
                } else {
                    MenuRow(icon: "timer", title: "Start Pomodoro") { timerManager.startPomodoro() }
                        .disabled(timerManager.isOnBreak)
                }
                if shift.adjustedWindowToday != nil {
                    MenuRow(icon: "arrow.uturn.backward", title: "Undo Late Start") { shift.clearAdjustedStart() }
                } else if shift.scheduledWindowToday != nil {
                    MenuRow(icon: "sunrise", title: "Start Shift from Now") { shift.startShift() }
                }
            }

            hairline

            VStack(spacing: 1) {
                MenuRow(icon: "gearshape", title: "Settings…", shortcut: "⌘,", action: actions.openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                MenuRow(icon: "power", title: "Quit EyeBreak", shortcut: "⌘Q") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(verbatim: shiftLine)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            if !timerManager.isPaused {
                pauseMenu
            }
        }
        .padding(.horizontal, 4)
    }

    /// Pause everything — breaks, water and nudges — for a while.
    private var pauseMenu: some View {
        Menu {
            Section("Pause all reminders") {
                ForEach(PauseDuration.allCases) { duration in
                    Button { timerManager.pause(until: duration.until()) } label: { Text(verbatim: duration.title) }
                }
            }
        } label: {
            Image(systemName: "pause.circle")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("Pause all reminders"))
        .accessibilityLabel(Text("Pause all reminders"))
    }

    /// A break that's about to start, or waiting for you to pause.
    private var breakIsDue: Bool {
        !timerManager.isOnBreak && (timerManager.isInWarningPeriod || timerManager.isWaitingForPause)
    }

    /// "On shift · 3:24 left, until 5:16 PM", "Shift starts at 9:00 AM", "Off the clock".
    private var shiftLine: String {
        guard let status = shift.status else { return String(localized: "No shift days picked") }
        switch status.phase {
        case .onShift:
            return String(localized: "On shift · \(ShiftText.short(for: status, now: shift.now)) left, until \(shift.schedule.clockText(for: status.window.end))")
        case .beforeShift:
            return String(localized: "Shift starts at \(shift.schedule.clockText(for: status.window.start))")
        case .offDuty:
            return String(localized: "Off the clock · next shift \(status.window.start.weekdayText())")
        }
    }

    private func pauseLine(_ reason: PauseReason) -> some View {
        HStack(spacing: 8) {
            Image(systemName: reason.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)
            if reason == .user {
                VStack(alignment: .leading, spacing: 0) {
                    Text("All reminders paused")
                        .font(.system(size: 12, weight: .medium))
                    Text(verbatim: PauseDuration.phrase(for: timerManager.pausedUntil))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: reason.label)
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            if reason == .user {
                Button("Resume") { timerManager.resume() }
                    .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    // MARK: - Hero
    /// The next break on a piece of glass: the one thing in the menu that floats.
    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                LiveCountdownRing(
                    remaining: timerManager.isOnBreak ? timerManager.breakTimeRemaining : timerManager.timeRemaining,
                    total: timerManager.isOnBreak ? timerManager.breakDuration : timerManager.workDuration,
                    style: .compact
                )
                .saturation(isDimmed ? 0 : 1)
                .opacity(isDimmed ? 0.5 : 1)

                Image(systemName: timerManager.isPaused ? "pause.fill" : isFocusBlock ? "timer" : "eye")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: breakCaption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(verbatim: timerManager.isRunning ? breakTime : String(localized: "Not running"))
                    .font(.system(size: timerManager.isRunning ? 26 : 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isDimmed ? .secondary : .primary)
                if let pomodoro = timerManager.pomodoro, timerManager.isFocusing || timerManager.isPomodoroBreak {
                    // The Pomodoro's own round, and how many blocks are done
                    HStack(spacing: 8) {
                        RoundDots(
                            filled: pomodoro.filled(every: settings.pomodoroLongBreakEvery, isOnBreak: timerManager.isPomodoroBreak),
                            total: settings.pomodoroLongBreakEvery
                        )
                        if pomodoro.completed > 0 {
                            Text(verbatim: String(localized: "\(pomodoro.completed) done"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                } else if settings.longBreakEvery > 0 && timerManager.isRunning {
                    RoundDots(
                        filled: timerManager.round.filled(every: settings.longBreakEvery, isOnBreak: timerManager.isOnBreak),
                        total: settings.longBreakEvery
                    )
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 4)

            if !timerManager.isRunning {
                Button("Start") { timerManager.start() }
                    .buttonStyle(AccentButtonStyle())
            }
        }
        .padding(12)
        .glassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: Theme.accent.opacity(0.10))
    }

    private var isDimmed: Bool { timerManager.pauseReason != nil && !timerManager.isOnBreak }

    /// A Pomodoro's block is running (not its break).
    private var isFocusBlock: Bool { timerManager.isFocusing && !timerManager.isOnBreak }

    private var breakCaption: String {
        if !timerManager.isRunning { return String(localized: "Breaks") }
        if timerManager.isOnBreak { return timerManager.isLongBreak ? String(localized: "Long break, time left") : String(localized: "Break, time left") }
        if timerManager.pauseReason != nil { return String(localized: "Paused") }
        if timerManager.isWaitingForPause {
            return timerManager.isInCall ? String(localized: "Break after your call") : String(localized: "Break when you pause typing")
        }
        if timerManager.isInWarningPeriod { return String(localized: "Break starting soon") }
        if isFocusBlock {
            return timerManager.nextBreakIsLong ? String(localized: "Pomodoro, then a long break") : String(localized: "Pomodoro, time left")
        }
        return timerManager.nextBreakIsLong ? String(localized: "Long break in") : String(localized: "Next break in")
    }

    private var breakTime: String {
        TimerManager.format(timerManager.isOnBreak ? timerManager.breakTimeRemaining : timerManager.timeRemaining)
    }

    // MARK: - Today
    private var today: some View {
        let misses = activity.misses(.eyes, on: shift.now).count + activity.misses(.water, on: shift.now).count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(verbatim: Rhythm.summary(misses: misses))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            RhythmLanes(activity: activity, now: shift.now, waterGoalML: settings.waterGoalML, waterUnit: settings.waterUnit)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Countdowns
    private var countdowns: some View {
        VStack(spacing: 2) {
            if settings.waterReminderEnabled {
                CountdownRow(
                    icon: waterManager.isDue ? "drop.fill" : "drop",
                    title: waterTitle,
                    value: waterValue,
                    dimmed: isDimmed
                ) {
                    Button("I Drank") { waterManager.drink() }
                        .buttonStyle(AccentButtonStyle(palette: .water))
                }
                .environment(\.palette, .water)
            }

            if settings.ambientRemindersEnabled {
                CountdownRow(icon: "eye", title: String(localized: "Next blink reminder in"), value: ambientManager.formattedTimeRemaining, dimmed: isDimmed) {
                    EmptyView()
                }
            }
        }
    }

    /// Water rides with the long break (so the next glass is due then), or keeps its own timer.
    private var waterTitle: String {
        waterManager.isDue ? String(localized: "Time to drink") : String(localized: "Next glass in")
    }

    private var waterValue: String {
        if waterManager.isDue { return String(localized: "Now") }
        if waterManager.ridesWithBreaks {
            return timerManager.timeUntilWaterBreak.map(TimerManager.format) ?? "—"
        }
        return waterManager.formattedTimeRemaining
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
    }
}

// MARK: - Round Dots
/// One dot per work interval (or Pomodoro block) in a round; the long break comes after the last.
private struct RoundDots: View {
    let filled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(filled) of \(total) before the long break"))
    }
}

// MARK: - Countdown Row
private struct CountdownRow<Accessory: View>: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String
    let value: String
    let dimmed: Bool
    /// Overrides the palette's accent, e.g. the shift's widget theme.
    var iconColor: Color? = nil
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor ?? palette.accent)
                .frame(width: 18)

            Text(verbatim: title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(verbatim: value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(dimmed ? .secondary : .primary)
            accessory()
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 28)
    }
}

// MARK: - Menu Row
/// Plain row with a quiet highlight on hover, like a native menu selection.
private struct MenuRow: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: LocalizedStringKey
    var shortcut: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var highlighted: Bool { isHovering && isEnabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(highlighted ? palette.onFill : Color.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(highlighted ? palette.onFill : Color.primary)
                Spacer()
                if let shortcut {
                    Text(verbatim: shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(highlighted ? palette.onFill.opacity(0.8) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlighted ? palette.fill : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
