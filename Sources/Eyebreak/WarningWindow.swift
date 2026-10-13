import AppKit
import SwiftUI
import Combine

class WarningWindowController {
    // MARK: - Properties
    private var window: NSWindow?
    var onSkip: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Public Methods
    func showWarning(timerManager: TimerManager) {
        // Hide existing warning first
        hideWarning()

        let warningView = WarningView(
            timerManager: timerManager,
            showsDryEye: timerManager.shouldShowDryEyeNudge,
            onSkip: { [weak self] in
                self?.hideWarning()
                self?.onSkip?()
            },
            onDismiss: { [weak self] in
                self?.hideWarning()
                self?.onDismiss?()
            }
        )

        window = ToastWindow.show(warningView.environment(\.palette, Palette.current(for: .breakOverlay)))
    }

    func hideWarning() {
        guard let existingWindow = window else { return }
        window = nil
        existingWindow.orderOut(nil)
    }
}

// MARK: - Toast Window
/// Borderless, transparent floating window pinned near the top of the main screen.
enum ToastWindow {
    enum Position { case topRight, topCenter }

    /// Transparent margin inside the window so the glass shadow isn't clipped.
    static let shadowMargin: CGFloat = 16
    private static let screenInset: CGFloat = 20

    /// - Parameter focusable: lets a click give the toast key focus (for ESC) without
    ///   activating the app or pulling focus away from what you're doing.
    static func show<Content: View>(_ content: Content, position: Position = .topRight, focusable: Bool = false) -> NSWindow? {
        guard let screen = NSScreen.main else { return nil }

        let hostingView = NSHostingView(rootView: content.padding(shadowMargin))
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)

        let rect = NSRect(origin: .zero, size: size)
        let window: NSWindow = focusable
            ? KeyablePanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            : NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The glass draws its own depth; a window shadow would outline the transparent margin
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        // Measured to the visible card rather than the window edge
        let screenFrame = screen.visibleFrame
        let inset = screenInset - shadowMargin
        let x = position == .topRight ? screenFrame.maxX - size.width - inset : screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height - inset
        window.setFrameOrigin(NSPoint(x: x, y: y))

        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window.animator().alphaValue = 1
        }
        return window
    }

    static func fadeOut(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}

// MARK: - Warning View
struct WarningView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.palette) private var palette
    let showsDryEye: Bool
    let onSkip: () -> Void
    let onDismiss: () -> Void

    private var secondsLeft: Int { Int(timerManager.timeRemaining) }

    var body: some View {
        if showsDryEye {
            dryEyeCard
        } else {
            standardCard
        }
    }

    // MARK: - Standard
    private var standardCard: some View {
        HStack(spacing: 14) {
            countdownBadge

            VStack(alignment: .leading, spacing: 2) {
                Text("Wrap up your work")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textStyle)

                Text("Break starting in \(secondsLeft)s")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryTextStyle)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            Button("Skip", action: onSkip)
                .buttonStyle(SoftButtonStyle())

            GlassCloseButton(action: onDismiss)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(width: 372)
        .themedGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), palette: palette, frosted: true)
    }

    // MARK: - Dry-Eye Nudge
    private var dryEyeCard: some View {
        VStack(spacing: 12) {
            DryEyeView()
                .frame(width: 200)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Your eyes will be like this.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(DryEyeView.skippedMessage(timerManager.skippedBreakStreak) + " Take this one.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                countdownBadge

                Text("Break in \(secondsLeft)s")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()

                Spacer(minLength: 8)

                Button("Skip anyway", action: onSkip)
                    .buttonStyle(SoftButtonStyle())
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 340)
        .overlay(alignment: .topTrailing) {
            GlassCloseButton(action: onDismiss)
                .padding(12)
        }
        .glassSurface(in: RoundedRectangle(cornerRadius: 26, style: .continuous), tint: Theme.alert.opacity(0.14), frosted: true)
    }

    // MARK: - Shared
    private var countdownBadge: some View {
        ZStack {
            LiveCountdownRing(
                remaining: timerManager.timeRemaining,
                total: timerManager.warningTime,
                style: .compact
            )

            Image(systemName: "eye")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}
