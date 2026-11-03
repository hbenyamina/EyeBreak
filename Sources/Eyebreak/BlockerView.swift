import SwiftUI

/// The water prompt carried inside a long break, so one interruption covers both.
struct BreakWaterPrompt {
    /// "250 ml"
    let glass: String
    let drink: () -> Void
}

/// The full-screen break: the countdown, and the one thing to do right now (look across
/// the room, then two slow blinks; on a long break, stand up first). Nothing else to read.
struct BlockerView: View {
    @ObservedObject var timerManager: TimerManager
    var water: BreakWaterPrompt? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            BreakBackdrop()

            VStack(spacing: 0) {
                Spacer()
                countdown
                Spacer(minLength: 36)
                BreakGuideCard(timerManager: timerManager, water: water, size: .large)
                Spacer()
                BreakActions(timerManager: timerManager)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea()
    }

    private var countdown: some View {
        let ringSize: CGFloat = 300
        let isLong = timerManager.breakTimeRemaining >= 60

        return ZStack {
            LiveCountdownRing(
                remaining: timerManager.breakTimeRemaining,
                total: timerManager.currentBreakDuration,
                style: .hero
            )
            .frame(width: ringSize, height: ringSize)

            Text(isLong ? TimerManager.format(timerManager.breakTimeRemaining) : timerManager.formattedBreakTimeRemaining)
                .font(.system(size: ringSize * (isLong ? 0.19 : 0.25), weight: .light))
                .monospacedDigit()
                .foregroundStyle(palette.textStyle)
                .environment(\.layoutDirection, .leftToRight)
                .frame(width: ringSize * 0.72, height: ringSize * 0.72)
                .themedGlass(in: Circle(), palette: palette)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(TimerManager.format(timerManager.breakTimeRemaining)) of break remaining"))
    }
}

// MARK: - Guide

/// What to do now, as a symbol, a line and one line of detail. The step changes as the
/// break runs; with VoiceOver it's spoken, since the blinks are done with eyes closed.
struct BreakGuideCard: View {
    enum Size { case large, compact }

    @ObservedObject var timerManager: TimerManager
    var water: BreakWaterPrompt?
    let size: Size

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drank = false

    private var step: BreakStep { timerManager.breakStep }
    private var large: Bool { size == .large }

    var body: some View {
        // Centred on the full screen; read from the leading edge inside the window
        VStack(alignment: large ? .center : .leading, spacing: large ? 14 : 6) {
            if timerManager.showsSkipNote {
                Text(skipNote)
                    .font(.system(size: large ? 14 : 11))
                    .foregroundStyle(palette.secondaryTextStyle)
                    .multilineTextAlignment(large ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: large ? 14 : 10) {
                Image(systemName: step.symbol)
                    .font(.system(size: large ? 24 : 15, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .frame(width: large ? 32 : 20)
                Text(step.title)
                    .font(.system(size: large ? 30 : 15, weight: large ? .medium : .semibold))
                    .foregroundStyle(palette.textStyle)
                    .contentTransition(.opacity)
            }
            Text(step.detail)
                .font(.system(size: large ? 16 : 12))
                .foregroundStyle(palette.secondaryTextStyle)
                .multilineTextAlignment(large ? .center : .leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            if let water, timerManager.breakIsOnYourFeet {
                waterRow(water)
                    .padding(.top, large ? 8 : 2)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: step)
        .padding(.horizontal, large ? 40 : 0)
        .padding(.vertical, large ? 26 : 0)
        .frame(maxWidth: large ? 640 : .infinity)
        .modifier(GuideSurface(large: large, palette: palette))
        .accessibilityElement(children: .combine)
        .onChange(of: step.title) { _, title in
            AccessibilityNotification.Announcement(title).post()
        }
    }

    /// Plain words, no picture of damage: what skipping does, and how short this one is.
    private var skipNote: String {
        let seconds = Int(timerManager.currentBreakDuration)
        return String(localized: "\(timerManager.skippedBreakStreak) breaks skipped in a row. Screens cut blinking by about two thirds; this one takes \(SettingsFormat.seconds(seconds)).")
    }

    private func waterRow(_ prompt: BreakWaterPrompt) -> some View {
        HStack(spacing: 10) {
            Image(systemName: drank ? "checkmark.circle.fill" : "drop.fill")
                .font(.system(size: large ? 14 : 12, weight: .medium))
                .foregroundStyle(Palette.water.accent)
            Text(drank ? String(localized: "Logged a glass of \(prompt.glass)") : String(localized: "Drink a glass while you're up"))
                .font(.system(size: large ? 14 : 12))
                .foregroundStyle(palette.textStyle)
            if !drank {
                Button("I Drank") {
                    prompt.drink()
                    drank = true
                }
                .buttonStyle(AccentButtonStyle(palette: .water, size: large ? .large : .small))
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// The large card floats on glass over the frost; the compact one sits inside a window.
private struct GuideSurface: ViewModifier {
    let large: Bool
    let palette: Palette

    func body(content: Content) -> some View {
        if large {
            content.themedGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), palette: palette)
        } else {
            content
        }
    }
}

// MARK: - Actions

/// "5 more minutes" (never a skip, twice at most), and esc to skip.
struct BreakActions: View {
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        HStack(spacing: 12) {
            if timerManager.canPostpone {
                Button("5 More Minutes") { timerManager.postpone() }
                    .buttonStyle(SoftButtonStyle(size: .large))
                    .help(Text("The break comes back in 5 minutes. It isn't counted as skipped."))
            }
            SkipHint()
        }
    }
}

// MARK: - Skip Hint
struct SkipHint: View {
    var action: LocalizedStringKey = "Skip"
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            KeyCap(label: "esc")
            Text(action)
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.secondaryTextStyle)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glassSurface(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Press Escape: \(Text(action))"))
    }
}

struct KeyCap: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    )
            )
            .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Backdrop
/// The desktop behind, frosted, under one still wash of the palette's colour.
/// Also used on its own for secondary displays.
struct BreakBackdrop: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            FrostedBackdrop(material: .fullScreenUI)
            palette.backdropTint
            palette.dark.opacity(0.18)
        }
        .ignoresSafeArea()
    }
}
