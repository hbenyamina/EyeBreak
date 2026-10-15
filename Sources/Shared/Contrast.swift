import AppKit
import SwiftUI

/// WCAG 2.1 contrast, so the widget themes stay legible by construction rather than by eye.
///
/// Surfaces are passed as a list of colours. The widget's are solid now, a single entry,
/// but a multi-stop surface is checked against both ends *and* the midpoint, because text
/// can sit anywhere along it.
enum Contrast {
    /// Small text (the widget's 10–12pt labels). WCAG AA.
    static let smallText: Double = 4.5

    struct Components: Hashable {
        let r: Double
        let g: Double
        let b: Double
    }

    static func components(of color: Color) -> Components {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return Components(r: Double(resolved.redComponent),
                          g: Double(resolved.greenComponent),
                          b: Double(resolved.blueComponent))
    }

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    static func luminance(_ color: Components) -> Double {
        0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }

    static func ratio(_ a: Components, _ b: Components) -> Double {
        let first = luminance(a)
        let second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    static func ratio(_ a: Color, _ b: Color) -> Double {
        ratio(components(of: a), components(of: b))
    }

    /// Every point on a gradient where text might land: both ends and the middle.
    static func samples(across stops: [Color]) -> [Components] {
        let parts = stops.map(components(of:))
        guard let first = parts.first, let last = parts.last, parts.count > 1 else { return parts }
        return parts + [Components(r: (first.r + last.r) / 2,
                                   g: (first.g + last.g) / 2,
                                   b: (first.b + last.b) / 2)]
    }

    /// Whether the ink sits lighter than the surface it's drawn on — light-on-dark,
    /// which macOS renders thinner than the nominal colour.
    static func inkIsLighterThanSurface(_ ink: Color, _ stops: [Color]) -> Bool {
        let inkLuminance = luminance(components(of: ink))
        let surfaceLuminance = samples(across: stops)
            .map(luminance)
            .reduce(0, +) / Double(max(1, samples(across: stops).count))
        return inkLuminance > surfaceLuminance
    }

    /// The most muted version of `ink` that still clears `minimumRatio` everywhere on
    /// the gradient — hierarchy without trading away legibility.
    ///
    /// This replaces drawing secondary text at reduced opacity: an alpha that looks
    /// right on one theme lands under 3:1 on another, because the blend depends on the
    /// surface underneath. Here the surface decides how far the mix can go, and returns
    /// `ink` untouched when even full strength can't reach the floor.
    static func muted(_ ink: Color, over stops: [Color], minimumRatio: Double) -> Color {
        let inkParts = components(of: ink)
        let points = samples(across: stops)
        guard let toward = points.last else { return ink }

        func candidate(_ strength: Double) -> Components {
            Components(r: strength * inkParts.r + (1 - strength) * toward.r,
                       g: strength * inkParts.g + (1 - strength) * toward.g,
                       b: strength * inkParts.b + (1 - strength) * toward.b)
        }
        func clears(_ strength: Double) -> Bool {
            let mixed = candidate(strength)
            return points.allSatisfy { ratio(mixed, $0) >= minimumRatio }
        }
        guard clears(1) else { return ink }

        var low = 0.0
        var high = 1.0
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if clears(middle) { high = middle } else { low = middle }
        }
        let result = candidate(high)
        return Color(red: result.r, green: result.g, blue: result.b)
    }
}
