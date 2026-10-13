import SwiftUI

// MARK: - Exercise Steps
enum ExerciseDirection: CaseIterable {
    case center, left, right, up, down, topLeft, topRight, bottomLeft, bottomRight, blink, lookAround

    /// Order the guide walks through; repeats if the break is longer than one pass.
    static let sequence: [ExerciseDirection] = [
        .center, .left, .right, .center, .up, .down,
        .topLeft, .bottomRight, .topRight, .bottomLeft, .blink, .lookAround,
    ]

    var title: String {
        switch self {
        case .center: return "Look at Center"
        case .left: return "Look Left"
        case .right: return "Look Right"
        case .up: return "Look Up"
        case .down: return "Look Down"
        case .topLeft: return "Look Top-Left"
        case .topRight: return "Look Top-Right"
        case .bottomLeft: return "Look Bottom-Left"
        case .bottomRight: return "Look Bottom-Right"
        case .blink: return "Blink"
        case .lookAround: return "Look Around"
        }
    }

    var icon: String {
        switch self {
        case .center: return "scope"
        case .left: return "arrow.left.circle.fill"
        case .right: return "arrow.right.circle.fill"
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .topLeft: return "arrow.up.left.circle.fill"
        case .topRight: return "arrow.up.right.circle.fill"
        case .bottomLeft: return "arrow.down.left.circle.fill"
        case .bottomRight: return "arrow.down.right.circle.fill"
        case .blink: return "eye.fill"
        case .lookAround: return "arrow.triangle.2.circlepath"
        }
    }

    /// Unit offset from screen centre (y grows downward).
    var offset: CGPoint {
        switch self {
        case .center, .blink: return .zero
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        case .up: return CGPoint(x: 0, y: -1)
        case .down: return CGPoint(x: 0, y: 1)
        case .topLeft: return CGPoint(x: -1, y: -1)
        case .topRight: return CGPoint(x: 1, y: -1)
        case .bottomLeft: return CGPoint(x: -1, y: 1)
        case .bottomRight: return CGPoint(x: 1, y: 1)
        case .lookAround: return CGPoint(x: 0, y: -1)
        }
    }

    var isContinuous: Bool { self == .blink || self == .lookAround }
}

// MARK: - Eye Exercise View
/// "Eye Exercise" break style: follow a glowing orb around a frosted screen.
struct EyeExerciseView: View {
    @ObservedObject var timerManager: TimerManager
    let holdSeconds: Int

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var elapsed: Int {
        max(Int(timerManager.currentBreakDuration - timerManager.breakTimeRemaining), 0)
    }

    private var direction: ExerciseDirection {
        let sequence = ExerciseDirection.sequence
        return sequence[(elapsed / max(holdSeconds, 1)) % sequence.count]
    }

    var body: some View {
        ZStack {
            BreakBackdrop()

            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                // Vertical reach stays clear of the header and instruction pills
                let range = CGSize(width: geo.size.width * 0.34, height: geo.size.height * 0.24)

                targetGuides(center: center, range: range)

                TimelineView(.animation(minimumInterval: 1 / 60, paused: !direction.isContinuous || reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ExerciseOrb(scale: orbScale(at: t))
                        .position(orbPosition(at: t, center: center, range: range))
                        .animation(.spring(response: 0.9, dampingFraction: 0.82), value: direction)
                }
            }

            VStack(spacing: 0) {
                header
                    .padding(.top, 56)
                Spacer()
                instruction
                    .padding(.bottom, 28)
                SkipHint()
                    .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Orb Motion
    private func orbPosition(at t: TimeInterval, center: CGPoint, range: CGSize) -> CGPoint {
        var offset = direction.offset
        if direction == .lookAround && !reduceMotion {
            let angle = t * 2 * .pi / 4 - .pi / 2
            offset = CGPoint(x: cos(angle), y: sin(angle))
        }
        return CGPoint(x: center.x + offset.x * range.width, y: center.y + offset.y * range.height)
    }

    private func orbScale(at t: TimeInterval) -> CGFloat {
        guard direction == .blink, !reduceMotion else { return 1 }
        // Quick close, slow open, about once a second
        let phase = t.truncatingRemainder(dividingBy: 1.1) / 1.1
        return phase < 0.2 ? 1 - phase / 0.2 * 0.8 : 0.2 + (phase - 0.2) / 0.8 * 0.8
    }

    // MARK: - Chrome
    private func targetGuides(center: CGPoint, range: CGSize) -> some View {
        ForEach(Array(ExerciseDirection.allCases.enumerated()), id: \.offset) { _, guide in
            if !guide.isContinuous {
                Circle()
                    .strokeBorder(palette.light.opacity(guide == direction ? 0.5 : 0.12), lineWidth: 1)
                    .frame(width: 22, height: 22)
                    .position(x: center.x + guide.offset.x * range.width, y: center.y + guide.offset.y * range.height)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                LiveCountdownRing(
                    remaining: timerManager.breakTimeRemaining,
                    total: timerManager.currentBreakDuration,
                    style: .compact
                )
                Text("\(Int(timerManager.breakTimeRemaining))")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textStyle)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Eye Exercise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textStyle)
                Text("Follow the moving dot with your eyes")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondaryText ?? palette.light.opacity(0.75))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 22)
        .padding(.vertical, 10)
        .themedGlass(in: Capsule(), palette: palette)
    }

    private var instruction: some View {
        HStack(spacing: 12) {
            Image(systemName: direction.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(palette.accent)
            Text(direction.title)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(palette.textStyle)
                .contentTransition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: direction)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .themedGlass(in: Capsule(), palette: palette)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(direction.title)
    }
}

// MARK: - Orb
private struct ExerciseOrb: View {
    var scale: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        Circle()
            .fill(palette.accent)
            .frame(width: 34, height: 34)
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
            .shadow(color: palette.accent.opacity(0.5), radius: 14)
            .scaleEffect(x: 1, y: scale)
            .accessibilityHidden(true)
    }
}
