import SwiftUI
import AppKit

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
    /// Liquid Glass on macOS 26+, frosted material with a hairline rim on earlier systems,
    /// and an opaque surface when Reduce Transparency is on.
    ///
    /// `frosted` adds a behind-window blur under the glass. Use it for small floating
    /// panels over an arbitrary desktop, where clear Liquid Glass alone hurts legibility.
    func glassSurface<S: InsettableShape>(in shape: S, tint: Color? = nil, frosted: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, frosted: frosted))
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

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let frosted: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            // Solid, so text keeps its contrast whatever is behind the window
            content
                .background {
                    ZStack {
                        shape.fill(Color(nsColor: .windowBackgroundColor))
                        if let tint { shape.fill(tint) }
                    }
                }
                .overlay { shape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 1) }
        } else if #available(macOS 26.0, *) {
            content
                .background {
                    if frosted {
                        FrostedBackdrop(material: .popover).clipShape(shape)
                    }
                }
                .glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            content
                .background {
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
    var label = String(localized: "Dismiss")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
