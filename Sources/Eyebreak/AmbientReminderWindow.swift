import AppKit
import SwiftUI

/// Shows the ambient reminder pill at the top-centre and fades it out on its own.
class AmbientReminderWindowController {
    private var window: NSWindow?
    private var dismissWork: DispatchWorkItem?

    func show(_ reminder: AmbientReminder, duration: TimeInterval) {
        hide()
        SoundManager.play(.ambient)

        let view = AmbientReminderView(reminder: reminder) { [weak self] in self?.hide() }
            .environment(\.palette, Palette.current(for: .ambientReminder))
        window = ToastWindow.show(view, position: .topCenter)

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func hide() {
        dismissWork?.cancel()
        dismissWork = nil
        guard let existingWindow = window else { return }
        window = nil
        ToastWindow.fadeOut(existingWindow)
    }
}

struct AmbientReminderView: View {
    let reminder: AmbientReminder
    let onDismiss: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                Group {
                    switch reminder.glyph {
                    case .symbol(let name):
                        Image(systemName: name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.accent)
                    case .emoji(let emoji):
                        Text(emoji).font(.system(size: 18))
                    }
                }
                .frame(width: 34, height: 34)
                .background(Circle().fill(palette.accent.opacity(0.14)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textStyle)
                    Text(reminder.message)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryTextStyle)
                }
                .fixedSize()
            }
            .padding(.leading, 8)
            .padding(.trailing, 20)
            .padding(.vertical, 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .themedGlass(in: Capsule(), palette: palette, frosted: true)
        .help("Click to dismiss")
        .accessibilityLabel("\(reminder.title). \(reminder.message)")
    }
}
