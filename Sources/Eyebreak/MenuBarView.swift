import SwiftUI

/// Actions that need the app coordinator (windows, schedule confirmation).
struct MenuActions {
    let takeBreak: () -> Void
    let showWater: () -> Void
    let showAmbient: () -> Void
    let openSettings: () -> Void
}

struct MenuBarView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var waterManager: WaterReminderManager
    @ObservedObject var ambientManager: AmbientReminderManager
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsStore
    let actions: MenuActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let reason = timerManager.pauseReason, reason != .user {
                pauseBanner(reason)
            }

            countdownCard

            todayProgress

            VStack(spacing: 2) {
                if timerManager.isRunning {
                    MenuRow(
                        icon: timerManager.isPaused ? "play.fill" : "pause.fill",
                        title: timerManager.isPaused ? "Resume" : "Pause"
                    ) {
                        timerManager.togglePause()
                    }
                }

                if timerManager.isInWarningPeriod && !timerManager.isOnBreak {
                    MenuRow(icon: "forward.fill", title: "Skip This Break") {
                        timerManager.skipBreak()
                    }
                }

                MenuRow(icon: "eye.fill", title: "Take Break Now", action: actions.takeBreak)
                    .disabled(timerManager.isOnBreak)

                if settings.waterReminderEnabled {
                    MenuRow(icon: "drop.fill", title: "Show Water Reminder", action: actions.showWater)
                        .environment(\.palette, .water)
                }
                if settings.ambientRemindersEnabled {
                    MenuRow(icon: "sparkles", title: "Show Ambient Reminder", action: actions.showAmbient)
                }
            }

            Divider()
                .opacity(0.5)

            VStack(spacing: 2) {
                MenuRow(icon: "gearshape.fill", title: "Settings…", shortcut: "⌘,", action: actions.openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                MenuRow(icon: "power", title: "Quit EyeBreak", shortcut: "⌘Q") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("EyeBreak")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func pauseBanner(_ reason: PauseReason) -> some View {
        HStack(spacing: 8) {
            Image(systemName: reason.icon)
                .foregroundStyle(Theme.accent)
            Text(reason.label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassSurface(in: Capsule(), tint: Theme.accent.opacity(0.12))
    }

    // MARK: - Countdowns
    /// All your health reminders at a glance.
    private var countdownCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    LiveCountdownRing(
                        remaining: timerManager.isOnBreak ? timerManager.breakTimeRemaining : timerManager.timeRemaining,
                        total: timerManager.isOnBreak ? timerManager.breakDuration : timerManager.workDuration,
                        style: .compact
                    )
                    .saturation(isDimmed ? 0 : 1)
                    .opacity(isDimmed ? 0.5 : 1)

                    Image(systemName: timerManager.isPaused ? "pause.fill" : "eye")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 0) {
                    Text(breakCaption)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(timerManager.isRunning ? breakTime : "Click to start")
                        .font(.system(size: timerManager.isRunning ? 22 : 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(isDimmed ? .secondary : .primary)
                }

                Spacer()

                if !timerManager.isRunning {
                    Button("Start") { timerManager.start() }
                        .buttonStyle(AccentButtonStyle())
                }
            }

            if settings.waterReminderEnabled || settings.ambientRemindersEnabled {
                Divider().opacity(0.4)
            }

            if settings.waterReminderEnabled {
                CountdownRow(
                    icon: waterManager.isDue ? "drop.fill" : "drop",
                    title: waterManager.isDue ? "Time to drink" : "Water in",
                    value: waterManager.isDue ? "Now" : waterManager.formattedTimeRemaining,
                    dimmed: isDimmed
                ) {
                    Button("I already drank") { waterManager.markDrank() }
                        .buttonStyle(AccentButtonStyle(palette: .water))
                }
                .environment(\.palette, .water)
            }

            if settings.ambientRemindersEnabled {
                CountdownRow(
                    icon: "sparkles",
                    title: "Ambient reminder in",
                    value: ambientManager.formattedTimeRemaining,
                    dimmed: isDimmed
                ) { EmptyView() }
            }
        }
        .padding(10)
        .glassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: Theme.accent.opacity(0.10))
    }

    private var isDimmed: Bool { timerManager.pauseReason != nil && !timerManager.isOnBreak }

    private var breakCaption: String {
        if !timerManager.isRunning { return "EyeBreak" }
        if timerManager.isOnBreak { return "Break time remaining" }
        if timerManager.pauseReason != nil { return "Paused" }
        return timerManager.isInWarningPeriod ? "Break starting soon" : "Next break in"
    }

    private var breakTime: String {
        TimerManager.format(timerManager.isOnBreak ? timerManager.breakTimeRemaining : timerManager.timeRemaining)
    }

    // MARK: - Today
    private var todayProgress: some View {
        let today = stats.today
        let goal = max(settings.dailyBreakGoal, 1)
        let progress = min(Double(today.breaksCompleted) / Double(goal), 1)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(today.breaksCompleted) of \(goal) breaks")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                if today.breaksSkipped > 0 {
                    Text("· \(today.breaksSkipped) skipped")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 6 : 0))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(today.breaksCompleted) of \(goal) breaks completed")
    }
}

// MARK: - Countdown Row
private struct CountdownRow<Accessory: View>: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String
    let value: String
    let dimmed: Bool
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(dimmed ? .secondary : .primary)
            }

            Spacer(minLength: 4)
            accessory()
        }
        .padding(.leading, 8)
    }
}

// MARK: - Menu Row
/// Plain row with a solid accent highlight on hover, like a native menu selection.
private struct MenuRow: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var highlighted: Bool { isHovering && isEnabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(highlighted ? palette.onFill : Color.secondary)
                    .frame(width: 18)
                Text(title)
                    .foregroundStyle(highlighted ? palette.onFill : Color.primary)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(highlighted ? palette.onFill.opacity(0.8) : Color.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlighted ? palette.fill : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
