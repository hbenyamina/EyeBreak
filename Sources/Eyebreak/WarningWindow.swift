import AppKit
import SwiftUI
import Combine

class WarningWindowController {
    // MARK: - Properties
    private var window: NSWindow?
    var onSkip: (() -> Void)?

    // MARK: - Public Methods
    func showWarning(timerManager: TimerManager, settings: AppSettings = .shared) {
        // Hide existing warning first
        hideWarning()

        let warningView = WarningView(timerManager: timerManager, settings: settings) { [weak self] in
            self?.hideWarning()
            self?.onSkip?()
        }

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

        // A short fade in and out, or none with Reduce Motion
        let fades = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        window.alphaValue = fades ? 0 : 1
        window.orderFrontRegardless()
        if fades {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                window.animator().alphaValue = 1
            }
        }
        return window
    }

    static func fadeOut(_ window: NSWindow) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}

// MARK: - Warning View
/// The optional heads-up before a break (off by default: the menu bar's eye fills instead).
struct WarningView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var settings: AppSettings
    @Environment(\.palette) private var palette
    let onSkip: () -> Void

    private var secondsLeft: Int { Int(timerManager.timeRemaining) }

    var body: some View {
        HStack(spacing: 14) {
            countdownBadge

            VStack(alignment: .leading, spacing: 2) {
                Text("Break in \(secondsLeft) s")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.textStyle)
                Text(settings.waitForPause ? "It waits for a pause in your typing." : "Wrap up what you're doing.")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryTextStyle)
            }

            Spacer(minLength: 8)

            if timerManager.canPostpone {
                Button("5 More Minutes") { timerManager.postpone() }
                    .buttonStyle(SoftButtonStyle())
            }
            Button("Skip", action: onSkip)
                .buttonStyle(SoftButtonStyle())
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(width: 440)
        .themedGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), palette: palette, frosted: true)
    }

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
