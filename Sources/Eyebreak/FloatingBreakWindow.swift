import AppKit
import SwiftUI

/// "Window" break style: a small glass card instead of covering the screen.
class FloatingBreakWindowController {
    private var window: NSWindow?
    var onSkip: (() -> Void)?

    func show(timerManager: TimerManager, water: BreakWaterPrompt?) {
        hide()
        let view = FloatingBreakView(timerManager: timerManager, water: water) { [weak self] in self?.onSkip?() }
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

/// A fixed size: the window is measured once, and the steps change underneath it.
struct FloatingBreakView: View {
    @ObservedObject var timerManager: TimerManager
    let water: BreakWaterPrompt?
    let onSkip: () -> Void

    @Environment(\.palette) private var palette

    /// Room for the steps' two lines, plus the water row and the skip note when they show.
    private var height: CGFloat {
        116 + (timerManager.breakIsOnYourFeet && water != nil ? 28 : 0) + (timerManager.showsSkipNote ? 32 : 0)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 10) {
                BreakGuideCard(timerManager: timerManager, water: water, size: .compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    if timerManager.canPostpone {
                        Button("5 More Minutes") { timerManager.postpone() }
                            .buttonStyle(SoftButtonStyle())
                    }
                    Button(action: onSkip) {
                        HStack(spacing: 6) {
                            Text("Skip")
                            Text(verbatim: "esc").foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.vertical, 14)
        .frame(width: 440, height: height, alignment: .topLeading)
        .themedGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), palette: palette, frosted: true)
    }
}
