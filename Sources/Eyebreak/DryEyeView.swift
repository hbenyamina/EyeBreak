import SwiftUI

/// A bloodshot, irritated eye, drawn flat — shown only after the user keeps skipping breaks.
struct DryEyeView: View {
    var body: some View {
        Canvas { context, size in
            DryEyeRenderer(size: size).draw(in: context)
        }
        .aspectRatio(1.75, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("A red, dry, irritated eye")
    }
}

extension DryEyeView {
    static func skippedMessage(_ count: Int) -> String {
        count == 1 ? "You skipped your last break." : "You've skipped \(count) breaks in a row."
    }
}

// MARK: - Renderer
private struct DryEyeRenderer {
    let size: CGSize

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var scale: CGFloat { w / 260 }
    private var irisCenter: CGPoint { CGPoint(x: w * 0.5, y: h * 0.53) }
    private var irisRadius: CGFloat { h * 0.33 }

    private let leftCorner = (x: 0.04, y: 0.56)
    private let rightCorner = (x: 0.96, y: 0.52)

    /// Almond outline with a heavy, drooping upper lid that hides the top of the iris.
    private var eyeShape: Path {
        var p = Path()
        let left = CGPoint(x: w * leftCorner.x, y: h * leftCorner.y)
        let right = CGPoint(x: w * rightCorner.x, y: h * rightCorner.y)
        p.move(to: left)
        p.addCurve(to: right, control1: CGPoint(x: w * 0.28, y: h * 0.15), control2: CGPoint(x: w * 0.70, y: h * 0.09))
        p.addCurve(to: left, control1: CGPoint(x: w * 0.72, y: h * 1.02), control2: CGPoint(x: w * 0.30, y: h * 1.04))
        p.closeSubpath()
        return p
    }

    private var lowerLid: Path {
        var p = Path()
        p.move(to: CGPoint(x: w * rightCorner.x, y: h * rightCorner.y))
        p.addCurve(
            to: CGPoint(x: w * leftCorner.x, y: h * leftCorner.y),
            control1: CGPoint(x: w * 0.72, y: h * 1.02),
            control2: CGPoint(x: w * 0.30, y: h * 1.04)
        )
        return p
    }

    private var lidCrease: Path {
        var p = Path()
        p.move(to: CGPoint(x: w * 0.12, y: h * 0.36))
        p.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.30),
            control1: CGPoint(x: w * 0.32, y: h * -0.02),
            control2: CGPoint(x: w * 0.68, y: h * -0.06)
        )
        return p
    }

    func draw(in context: GraphicsContext) {
        var eye = context
        eye.clip(to: eyeShape)

        drawSclera(in: eye)
        drawVeins(in: eye)
        drawIris(in: eye)

        // Raw, irritated rims
        context.stroke(lowerLid, with: .color(Color(red: 1.0, green: 0.42, blue: 0.48).opacity(0.85)), lineWidth: 3 * scale)
        context.stroke(eyeShape, with: .color(Color(red: 0.32, green: 0.02, blue: 0.06)), lineWidth: 2.5 * scale)
        context.stroke(
            lidCrease,
            with: .color(.white.opacity(0.14)),
            style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round)
        )
    }

    private func drawSclera(in context: GraphicsContext) {
        // Irritated pink rather than white
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.98, green: 0.80, blue: 0.79)))
    }

    private func drawVeins(in context: GraphicsContext) {
        var rng = SeededRandom(seed: 0xE1E_B4EA)
        var veins: [(path: Path, width: CGFloat)] = []

        // (x, y) as fractions of the canvas; veins grow from the edges toward the iris.
        let roots: [(Double, Double)] = [
            (0.05, 0.55), (0.08, 0.48), (0.08, 0.64), (0.14, 0.42), (0.14, 0.72), (0.20, 0.36),
            (0.95, 0.51), (0.92, 0.44), (0.92, 0.60), (0.86, 0.36), (0.86, 0.70), (0.80, 0.30),
            (0.34, 0.92), (0.50, 0.96), (0.66, 0.92), (0.30, 0.24), (0.68, 0.20),
        ]
        for (x, y) in roots {
            let start = CGPoint(x: w * x, y: h * y)
            let heading = atan2(irisCenter.y - start.y, irisCenter.x - start.x)
            growVein(from: start, heading: heading, width: (1.6 + rng.next() * 0.8) * scale, depth: 0, rng: &rng, into: &veins)
        }

        let veinColor = Color(red: 0.80, green: 0.08, blue: 0.16)
        for vein in veins {
            context.stroke(vein.path, with: .color(veinColor), style: StrokeStyle(lineWidth: vein.width, lineCap: .round, lineJoin: .round))
        }
    }

    private func growVein(
        from start: CGPoint,
        heading: Double,
        width: CGFloat,
        depth: Int,
        rng: inout SeededRandom,
        into veins: inout [(path: Path, width: CGFloat)]
    ) {
        var path = Path()
        path.move(to: start)
        var point = start
        var heading = heading
        let step = w * (depth == 0 ? 0.038 : 0.026)
        let segments = 4 + Int(rng.next() * 4) - depth

        for _ in 0..<max(segments, 2) {
            heading += (rng.next() - 0.5) * 0.9
            let next = CGPoint(x: point.x + CGFloat(cos(heading)) * step, y: point.y + CGFloat(sin(heading)) * step)
            let control = CGPoint(
                x: (point.x + next.x) / 2 + CGFloat(rng.next() - 0.5) * step * 0.7,
                y: (point.y + next.y) / 2 + CGFloat(rng.next() - 0.5) * step * 0.7
            )
            path.addQuadCurve(to: next, control: control)

            if depth < 2 && rng.next() < 0.38 {
                let fork = heading + (rng.next() < 0.5 ? -1 : 1) * (0.5 + rng.next() * 0.7)
                growVein(from: next, heading: fork, width: width * 0.6, depth: depth + 1, rng: &rng, into: &veins)
            }
            point = next
        }
        veins.append((path, width))
    }

    private func drawIris(in context: GraphicsContext) {
        let c = irisCenter
        let r = irisRadius
        let iris = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

        context.fill(iris, with: .color(Color(red: 0.40, green: 0.22, blue: 0.14)))

        // Fibres
        var fibres = Path()
        for i in 0..<56 {
            let a = Double(i) / 56 * 2 * .pi
            fibres.move(to: CGPoint(x: c.x + r * 0.45 * CGFloat(cos(a)), y: c.y + r * 0.45 * CGFloat(sin(a))))
            fibres.addLine(to: CGPoint(x: c.x + r * 0.9 * CGFloat(cos(a + 0.05)), y: c.y + r * 0.9 * CGFloat(sin(a + 0.05))))
        }
        context.stroke(fibres, with: .color(Color(red: 0.85, green: 0.58, blue: 0.42).opacity(0.22)), lineWidth: 0.8 * scale)

        // Dark limbal ring
        context.stroke(iris, with: .color(Color(red: 0.08, green: 0.02, blue: 0.02).opacity(0.85)), lineWidth: r * 0.12)

        // Pupil
        let p = r * 0.42
        context.fill(Path(ellipseIn: CGRect(x: c.x - p, y: c.y - p, width: p * 2, height: p * 2)), with: .color(.black))

        // Glossy reflections — a dull, dry eye still catches a little light
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - r * 0.52, y: c.y - r * 0.5, width: r * 0.34, height: r * 0.26)),
            with: .color(.white.opacity(0.8))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: c.x + r * 0.26, y: c.y + r * 0.2, width: r * 0.12, height: r * 0.12)),
            with: .color(.white.opacity(0.45))
        )
    }
}

// MARK: - Deterministic RNG
/// Same veins on every render, so the eye doesn't flicker between frames.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
