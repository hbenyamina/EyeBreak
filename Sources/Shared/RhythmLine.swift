import SwiftUI

/// One habit's rhythm line across a window of time: drawn up to `now`, a hairline for
/// the rest of the window, and a dot where the day is now. The same view draws it in the
/// widget, the menu and Statistics, so the three always agree.
struct RhythmLine: View {
    let misses: [Date]
    let window: DateInterval
    let now: Date
    let color: Color
    var lineWidth: CGFloat = 2
    /// The rest of the window, still ahead.
    var trackColor: Color = Theme.Page.hairline

    var body: some View {
        GeometryReader { geometry in
            let inset = lineWidth + 2
            let height = max(geometry.size.height - inset * 2, 1)
            let width = geometry.size.width
            let points = Rhythm.points(misses: misses, window: window, now: now)
            let place = { (point: (x: Double, y: Double)) in
                CGPoint(x: point.x * width, y: inset + (1 - point.y) * height)
            }

            ZStack(alignment: .topLeading) {
                // What's left of the window, at the line's resting height
                Path { path in
                    let x = (points.last?.x ?? 0) * width
                    path.move(to: CGPoint(x: x, y: inset))
                    path.addLine(to: CGPoint(x: width, y: inset))
                }
                .stroke(trackColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))

                if let first = points.first, let last = points.last {
                    Path { path in
                        path.move(to: place(first))
                        for point in points.dropFirst() { path.addLine(to: place(point)) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                    Circle()
                        .fill(color)
                        .frame(width: lineWidth * 2.5, height: lineWidth * 2.5)
                        .position(place(last))
                }
            }
        }
        // Time runs the way the page reads: right to left in Arabic
        .flipsForRightToLeftLayoutDirection(true)
        .accessibilityElement()
        .accessibilityLabel(Text(Rhythm.summary(misses: misses.count)))
    }
}

/// A day-by-day line for one habit: each day's score, flat along the top on days you kept
/// up. The week's track runs the full width, and a day with nothing recorded is an open
/// ring on it, so a first week reads as a line in progress rather than stray dots.
struct WeekLine: View {
    /// Oldest first; nil for a day with nothing recorded.
    let scores: [Double?]
    let color: Color
    var lineWidth: CGFloat = 2
    var trackColor: Color = Theme.Page.hairline

    var body: some View {
        GeometryReader { geometry in
            let inset = lineWidth + 2
            let height = max(geometry.size.height - inset * 2, 1)
            let step = scores.count > 1 ? geometry.size.width / CGFloat(scores.count - 1) : 0
            let point = { (index: Int, score: Double) in
                CGPoint(x: CGFloat(index) * step, y: inset + (1 - max(score, Rhythm.floor)) * height)
            }
            Path { path in
                path.move(to: CGPoint(x: 0, y: inset))
                path.addLine(to: CGPoint(x: geometry.size.width, y: inset))
            }
            .stroke(trackColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))

            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                if score == nil {
                    Circle()
                        .strokeBorder(trackColor, lineWidth: 1.5)
                        .background(Circle().fill(Theme.Page.paper))
                        .frame(width: lineWidth * 3, height: lineWidth * 3)
                        .position(x: CGFloat(index) * step, y: inset)
                }
            }

            Path { path in
                var drawing = false
                for (index, score) in scores.enumerated() {
                    guard let score else { drawing = false; continue }
                    if drawing { path.addLine(to: point(index, score)) } else { path.move(to: point(index, score)) }
                    drawing = true
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                if let score {
                    Circle().fill(color)
                        .frame(width: lineWidth * 2.2, height: lineWidth * 2.2)
                        .position(point(index, score))
                }
            }
        }
        .flipsForRightToLeftLayoutDirection(true)
    }
}

/// How each habit is named and drawn everywhere: violet eyes, aqua water.
extension Habit {
    var title: String { self == .eyes ? String(shared: "Eyes") : String(shared: "Water") }
    var symbol: String { self == .eyes ? "eye.fill" : "drop.fill" }

    func color(fullColor: Bool) -> Color {
        guard fullColor else { return .primary }
        return self == .eyes ? Theme.accent : Theme.Water.deep
    }
}

/// Day names under a `WeekLine`, each centred on its point (the ends held inside the edges).
struct WeekLabels: View {
    let labels: [String]
    var color: Color = Theme.Page.secondaryInk
    var size: CGFloat = 11

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let step = labels.count > 1 ? width / CGFloat(labels.count - 1) : 0
            // Half the widest label, so the first and last stay inside the line's ends
            let half = CGFloat(labels.map(\.count).max() ?? 1) * size * 0.32
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                // SwiftUI mirrors positions right to left in Arabic, matching the flipped line
                Text(label)
                    .font(.system(size: size))
                    .foregroundStyle(color)
                    .fixedSize()
                    .position(x: min(max(CGFloat(index) * step, half), width - half), y: (size + 4) / 2)
            }
        }
        .frame(height: size + 4)
    }
}
