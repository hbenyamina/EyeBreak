import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    // MARK: - Callbacks
    var onOverride: (() -> Void)?
    /// Plain ESC while one of our windows has focus. Return true to consume the key.
    var onEscape: (() -> Bool)?

    // MARK: - Properties
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // MARK: - Initialization
    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods
    func startMonitoring() {
        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor for when app is focused (blocker window)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            let noModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            if event.keyCode == 53 && noModifiers && self?.onEscape?() == true {
                return nil
            }
            return event
        }
    }

    func stopMonitoring() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // MARK: - Private Methods
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Option+Shift+Escape (⌥⇧⎋)
        let escapeKeyCode: UInt16 = 53

        // Check if Option and Shift are pressed (and no other modifiers like Command)
        let modifiersMatch = event.modifierFlags.contains(.option) &&
                            event.modifierFlags.contains(.shift) &&
                            !event.modifierFlags.contains(.command) &&
                            !event.modifierFlags.contains(.control)

        if event.keyCode == escapeKeyCode && modifiersMatch {
            DispatchQueue.main.async { [weak self] in
                self?.onOverride?()
            }
            return true
        }
        return false
    }
}
