import AppKit
import SwiftUI

// MARK: - Key-capable Windows
/// Borderless windows can't become key by default, which would swallow ESC.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Floating panel that takes key focus when clicked without activating the app.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Full-screen Overlay
/// Frosted overlay across every display: the given content on the primary screen,
/// the plain frosted backdrop on the others.
class OverlayWindowController {
    private var windows: [NSWindow] = []
    var isVisible: Bool { !windows.isEmpty }

    func show<Content: View>(palette: Palette, @ViewBuilder content: () -> Content) {
        hide() // Clean up any existing windows

        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return }
        let primaryContent = content()

        for screen in screens {
            let isPrimary = screen == primaryScreen
            let window = makeWindow(for: screen)
            if isPrimary {
                window.contentView = NSHostingView(rootView: primaryContent.environment(\.palette, palette))
            } else {
                window.contentView = NSHostingView(rootView: BreakBackdrop().environment(\.palette, palette))
            }
            windows.append(window)
            if isPrimary {
                // Key + active so ESC reaches the app's local key monitor
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
    }

    func hide() {
        guard !windows.isEmpty else { return }
        let windowsToClose = windows
        windows.removeAll()

        for window in windowsToClose {
            window.contentView = nil  // Remove SwiftUI view first
            window.orderOut(nil)
        }
        // Hand focus back to whatever the user was doing
        NSApp.deactivate()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Transparent so the frosted backdrop can blur the desktop behind it
        window.backgroundColor = .clear
        window.isOpaque = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = false
        window.isReleasedWhenClosed = false

        // Make window appear on all spaces and above fullscreen apps
        window.setFrame(screen.frame, display: true)
        return window
    }
}
