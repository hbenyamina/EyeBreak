import SwiftUI

// MARK: - Tapered Arc
/// A ring segment that swells from a hairline tail into a rounded head.
///
/// The head is pinned at 12 o'clock and `progress` (1 → 0) trims the tail clockwise,
/// so the arc that remains is always the widest part of the ring: it gets heavier
/// toward the end of the countdown.
struct TaperedArc: Shape {
    var progress: Double
    var minWidth: CGFloat
    var maxWidth: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let progress = min(max(progress, 0), 1)
        guard progress > 0.001 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - maxWidth / 2
        let tail = 1 - progress
        let steps = max(Int(progress * 240), 8)

        // `t` is a fraction of a full turn, clockwise from 12 o'clock.
        func angle(_ t: Double) -> Double { t * 2 * .pi - .pi / 2 }
        // Ease-in so most of the swelling happens close to the head.
        func width(_ t: Double) -> CGFloat { minWidth + (maxWidth - minWidth) * CGFloat(t * t) }
        func point(_ a: Double, _ r: CGFloat, from c: CGPoint) -> CGPoint {
            CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
        }
        func t(_ i: Int) -> Double { tail + progress * Double(i) / Double(steps) }

        // Half-disc cap centred on the ring's midline at `t`, sweeping from `from` by π.
        func addCap(_ path: inout Path, at t: Double, from start: Double) {
            let c = point(angle(t), radius, from: center)
            let r = width(t) / 2
            for k in 1...16 {
                path.addLine(to: point(start + .pi * Double(k) / 16, r, from: c))
            }
        }

        var path = Path()
        for i in 0...steps {
            let p = point(angle(t(i)), radius + width(t(i)) / 2, from: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        addCap(&path, at: 1, from: angle(1))
        for i in stride(from: steps, through: 0, by: -1) {
            path.addLine(to: point(angle(t(i)), radius - width(t(i)) / 2, from: center))
        }
        addCap(&path, at: tail, from: angle(tail) + .pi)
        path.closeSubpath()
        return path
    }
}

// MARK: - Countdown Ring
/// Tapered ring in one solid colour over a faint groove, with a single soft glow.
struct CountdownRing: View {
    struct Style {
        var minWidth: CGFloat
        var maxWidth: CGFloat
        var glow: CGFloat

        static let hero = Style(minWidth: 2.5, maxWidth: 22, glow: 16)
        static let compact = Style(minWidth: 1, maxWidth: 4.5, glow: 0)
    }

    var progress: Double
    var style: Style = .hero

    @Environment(\.palette) private var palette

    var body: some View {
        let arc = TaperedArc(progress: progress, minWidth: style.minWidth, maxWidth: style.maxWidth)

        ZStack {
            Circle()
                .inset(by: style.maxWidth / 2)
                .stroke(Color.primary.opacity(0.08), lineWidth: style.maxWidth * 0.5)

            if style.glow > 0 {
                arc.fill(palette.accent).blur(radius: style.glow).opacity(0.45)
            }
            arc.fill(palette.accent)
        }
    }
}

// MARK: - Live Countdown Ring
/// Feeds `CountdownRing` from a once-per-second timer. Each tick animates linearly
/// toward where the *next* tick will land, so the sweep is continuous and reaches
/// zero exactly when the countdown does instead of trailing a second behind.
struct LiveCountdownRing: View {
    var remaining: TimeInterval
    var total: TimeInterval
    var style: CountdownRing.Style = .hero

    @State private var progress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CountdownRing(progress: progress ?? fraction(remaining), style: style)
            .onAppear(perform: advance)
            .onChange(of: remaining) { _, _ in advance() }
    }

    private func fraction(_ seconds: TimeInterval) -> Double {
        total > 0 ? min(max(seconds / total, 0), 1) : 0
    }

    /// With Reduce Motion the ring steps once a second instead of sweeping.
    private func advance() {
        guard !reduceMotion else {
            progress = fraction(remaining)
            return
        }
        withAnimation(.linear(duration: 1)) {
            progress = fraction(remaining - 1)
        }
    }
}
