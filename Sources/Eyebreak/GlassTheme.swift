import SwiftUI
import AppKit

// MARK: - Palette
/// Solid colours only. Each ramp runs light → bright → accent → deep → dark; accents mark
/// actions, selection and state, never decoration.
enum Theme {
    // Eyes — breaks, exercises, ambient nudges and the app's own chrome: violet
    static let light  = Color(red: 0.90, green: 0.85, blue: 1.00)   // #E6D9FF lavender mist
    static let bright = Color(red: 0.73, green: 0.60, blue: 1.00)   // #BA99FF
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.97)   // #8C5CF7 violet
    static let deep   = Color(red: 0.42, green: 0.21, blue: 0.88)   // #6B36E0, white text 6.5:1
    static let dark   = Color(red: 0.18, green: 0.08, blue: 0.44)   // #2E1470

    // Water — clear, luminous aqua-blue
    enum Water {
        static let light  = Color(red: 0.91, green: 0.99, blue: 1.00)   // #E8FCFF
        static let bright = Color(red: 0.37, green: 0.88, blue: 1.00)   // #5FE0FF aqua
        static let accent = Color(red: 0.08, green: 0.72, blue: 1.00)   // #14B8FF vivid sky
        static let deep   = Color(red: 0.02, green: 0.56, blue: 0.96)   // #0490F5 clear blue
        static let dark   = Color(red: 0.04, green: 0.38, blue: 0.84)   // #0A62D6
        /// Text on aqua fills: 8:1 against `bright`, where white would fail.
        static let ink    = Color(red: 0.02, green: 0.21, blue: 0.37)   // #06355E
    }

    /// Dry-eye warning only: irritated red, deliberately outside both calm palettes.
    static let alert = Color(red: 0.92, green: 0.12, blue: 0.30)   // #EB1F4D
}

// MARK: - Frosted Backdrop
/// Blurs whatever is *behind the window* (desktop, other apps). SwiftUI materials
/// only blur content inside the window, which is empty for our overlays.
struct FrostedBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Glass Surfaces
extension View {
    /// Liquid Glass on macOS 26+, frosted material with a hairline rim on earlier systems.
    ///
    /// `frosted` adds a behind-window blur under the glass. Use it for small floating
    /// panels over an arbitrary desktop, where clear Liquid Glass alone hurts legibility.
    @ViewBuilder
    func glassSurface<S: InsettableShape>(in shape: S, tint: Color? = nil, frosted: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            background {
                if frosted {
                    FrostedBackdrop(material: .popover).clipShape(shape)
                }
            }
            .glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            background {
                ZStack {
                    if frosted {
                        FrostedBackdrop(material: .popover).clipShape(shape)
                    }
                    shape.fill(.ultraThinMaterial)
                    if let tint {
                        shape.fill(tint)
                    }
                }
            }
            .overlay { shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
    }

    /// `.glass` button style on macOS 26+, bordered fallback otherwise.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

// MARK: - Accent Button
/// Solid accent capsule for a surface's main action. System prominent styles turn grey
/// in non-key windows, and our toasts never become key, so this draws its own fill.
struct AccentButtonStyle: ButtonStyle {
    enum Size { case small, large }

    var palette: Palette = .eyes
    var size: Size = .small

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size == .large ? 14 : 12, weight: .medium))
            .foregroundStyle(palette.onFill)
            .padding(.horizontal, size == .large ? 18 : 11)
            .padding(.vertical, size == .large ? 8 : 4)
            .background(Capsule().fill(palette.fill.opacity(configuration.isPressed ? 0.8 : 1)))
            .contentShape(Capsule())
    }
}

// MARK: - Soft Button
/// Quiet capsule for secondary actions on toasts and overlays. Unlike `.glass`, its label
/// stays full-strength in windows that never become key.
struct SoftButtonStyle: ButtonStyle {
    var size: AccentButtonStyle.Size = .small

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size == .large ? 14 : 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, size == .large ? 18 : 11)
            .padding(.vertical, size == .large ? 8 : 4)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.09)))
            .contentShape(Capsule())
    }
}

// MARK: - Close Button
struct GlassCloseButton: View {
    var label = "Dismiss"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
