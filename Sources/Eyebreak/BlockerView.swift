import SwiftUI

struct BlockerView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.palette) private var palette
    @State private var quote: String = ""
    @State private var showsDryEye = false

    var body: some View {
        ZStack {
            BreakBackdrop()

            VStack(spacing: 0) {
                Spacer()

                countdown

                Spacer()

                if showsDryEye {
                    DryEyeNudgeCard(skippedCount: timerManager.skippedBreakStreak, compact: false)
                } else {
                    quoteCard
                }

                Spacer()

                SkipHint()
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea()
        .onAppear {
            quote = QuoteManager.shared.getRandomQuote()
            showsDryEye = timerManager.shouldShowDryEyeNudge
        }
    }

    // MARK: - Countdown
    private var countdown: some View {
        // Shrink when the dry-eye card needs the room, so both fit on a laptop screen
        let ringSize: CGFloat = showsDryEye ? 310 : 380
        let isLong = timerManager.breakTimeRemaining >= 60

        return ZStack {
            LiveCountdownRing(
                remaining: timerManager.breakTimeRemaining,
                total: timerManager.breakDuration,
                style: showsDryEye ? .heroCompact : .hero
            )
            .frame(width: ringSize, height: ringSize)

            VStack(spacing: 0) {
                Text(isLong ? TimerManager.format(timerManager.breakTimeRemaining) : timerManager.formattedBreakTimeRemaining)
                    .font(.system(size: ringSize * (isLong ? 0.2 : 0.26), weight: .light))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.25), value: timerManager.breakTimeRemaining)
                    .foregroundStyle(palette.textStyle)

                Text(isLong ? "remaining" : "seconds")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.secondaryText ?? palette.light.opacity(0.7))
            }
            .frame(width: ringSize * 0.75, height: ringSize * 0.75)
            .themedGlass(in: Circle(), palette: palette)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(TimerManager.format(timerManager.breakTimeRemaining)) of break remaining")
    }

    // MARK: - Messages
    private var quoteCard: some View {
        Text(quote)
            .font(.system(size: 20))
            .foregroundStyle(palette.textStyle)
            .opacity(0.9)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .themedGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous), palette: palette)
            .frame(maxWidth: 720)
    }
}

// MARK: - Dry-Eye Nudge Card
struct DryEyeNudgeCard: View {
    let skippedCount: Int
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            DryEyeView()
                .frame(width: compact ? 200 : 280)

            VStack(spacing: 6) {
                Text("Your eyes will be like this.")
                    .font(.system(size: compact ? 17 : 26, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(DryEyeView.skippedMessage(skippedCount) + " Look at something 20 feet away.")
                    .font(.system(size: compact ? 12 : 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, compact ? 18 : 40)
        .padding(.top, compact ? 16 : 28)
        .padding(.bottom, compact ? 18 : 30)
        .glassSurface(in: RoundedRectangle(cornerRadius: compact ? 26 : 34, style: .continuous), tint: Theme.alert.opacity(0.16))
        .frame(maxWidth: compact ? 360 : 640)
    }
}

// MARK: - Skip Hint
struct SkipHint: View {
    var action = "skip"

    var body: some View {
        HStack(spacing: 8) {
            Text("Press")
            KeyCap(label: "esc")
            Text("to \(action)")
        }
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glassSurface(in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Press Escape to \(action)")
    }
}

struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
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
