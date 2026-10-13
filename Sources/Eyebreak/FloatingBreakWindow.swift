import AppKit
import SwiftUI

/// "Floating Window" break style: a small glass card instead of covering the screen.
class FloatingBreakWindowController {
    private var window: NSWindow?
    var onClose: (() -> Void)?

    func show(timerManager: TimerManager) {
        hide()
        let view = FloatingBreakView(timerManager: timerManager) { [weak self] in self?.onClose?() }
        window = ToastWindow.show(
            view.environment(\.palette, Palette.current(for: .breakOverlay)),
            position: .topCenter,
            focusable: true
        )
    }

    func hide() {
        guard let existingWindow = window else { return }
        window = nil
        ToastWindow.fadeOut(existingWindow)
    }
}

struct FloatingBreakView: View {
    @ObservedObject var timerManager: TimerManager
    let onClose: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                LiveCountdownRing(
                    remaining: timerManager.breakTimeRemaining,
                    total: timerManager.currentBreakDuration,
                    style: CountdownRing.Style(minWidth: 1.5, maxWidth: 6, glow: 0)
                )
                Text(timerManager.breakTimeRemaining >= 60
                     ? TimerManager.format(timerManager.breakTimeRemaining)
                     : timerManager.formattedBreakTimeRemaining)
                    .font(.system(size: timerManager.breakTimeRemaining >= 60 ? 13 : 18, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(palette.textStyle)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text("Time for a Break")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textStyle)
                Text("Look 20 feet away for \(SettingsFormat.seconds(Int(timerManager.currentBreakDuration)))")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryTextStyle)
                Button("Close (or press ESC)", action: onClose)
                    .buttonStyle(SoftButtonStyle())
                    .padding(.top, 4)
            }
            .fixedSize()
        }
        .padding(.leading, 14)
        .padding(.trailing, 22)
        .padding(.vertical, 14)
        .themedGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), palette: palette, frosted: true)
    }
}
