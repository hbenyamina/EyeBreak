import AppKit
import SwiftUI

class WaterReminderWindowController {
    // MARK: - Properties
    private var window: NSWindow?
    private let overlay = OverlayWindowController()
    var isVisible: Bool { window != nil || overlay.isVisible }

    // MARK: - Public Methods
    func showReminder(waterManager: WaterReminderManager, settings: AppSettings = .shared) {
        hideReminder()

        let content = WaterReminderContent.make(settings: settings)
        let palette = Palette.current(for: .waterReminder)
        let actions = WaterReminderActions(
            drinkNow: { waterManager.markDrank() },
            alreadyDrank: { waterManager.markDrank() },
            snooze: { waterManager.snooze() }
        )

        SoundManager.play(.water)
        switch settings.waterReminderStyle {
        case .floatingWindow:
            window = ToastWindow.show(
                WaterReminderView(content: content, actions: actions).environment(\.palette, palette),
                position: .topRight,
                focusable: true
            )
        case .blurScreen:
            overlay.show(palette: palette) {
                WaterBlurOverlayView(content: content, actions: actions)
            }
        }
    }

    func hideReminder() {
        if let existingWindow = window {
            window = nil
            ToastWindow.fadeOut(existingWindow)
        }
        overlay.hide()
    }
}

// MARK: - Content
struct WaterReminderContent {
    let icon: String
    let title: String
    let message: String

    static func make(settings: AppSettings) -> WaterReminderContent {
        let custom = settings.useCustomWaterReminder
        let message = custom && !settings.customWaterReminderMessage.isEmpty
            ? settings.customWaterReminderMessage
            : WaterReminderManager.messages.randomElement() ?? "Take a moment to drink some water."
        return WaterReminderContent(
            icon: custom ? settings.customWaterReminderIcon : "drop.fill",
            title: WaterReminderManager.titles.randomElement() ?? "Time for Water!",
            message: message
        )
    }
}

struct WaterReminderActions {
    let drinkNow: () -> Void
    let alreadyDrank: () -> Void
    let snooze: () -> Void
}

// MARK: - Water Icon
/// Water glyph in solid aqua.
struct WaterIcon: View {
    let symbol: String
    let size: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(palette.accent)
            .accessibilityHidden(true)
    }
}

// MARK: - Floating View
struct WaterReminderView: View {
    let content: WaterReminderContent
    let actions: WaterReminderActions

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                WaterIcon(symbol: content.icon, size: 18)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(palette.accent.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textStyle)
                    Text(content.message)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondaryTextStyle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                GlassCloseButton(label: "Remind me in 10 minutes", action: actions.snooze)
            }

            HStack(spacing: 8) {
                Button("Thanks, I'll drink water now", action: actions.drinkNow)
                    .buttonStyle(AccentButtonStyle(palette: palette))
                Button("I already drank", action: actions.alreadyDrank)
                    .buttonStyle(SoftButtonStyle())
            }
            .padding(.leading, 56)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .frame(width: 400)
        .themedGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), palette: palette, frosted: true)
    }
}

// MARK: - Blur Overlay View
struct WaterBlurOverlayView: View {
    let content: WaterReminderContent
    let actions: WaterReminderActions

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            BreakBackdrop()

            VStack(spacing: 22) {
                WaterIcon(symbol: content.icon, size: 46)
                    .frame(width: 104, height: 104)
                    .themedGlass(in: Circle(), palette: palette)

                VStack(spacing: 8) {
                    Text(content.title)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(palette.textStyle)
                    Text(content.message)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.secondaryText ?? palette.light.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button("Thanks, I'll drink water now", action: actions.drinkNow)
                        .buttonStyle(AccentButtonStyle(palette: palette, size: .large))
                    Button("I already drank", action: actions.alreadyDrank)
                        .buttonStyle(SoftButtonStyle(size: .large))
                }
                .padding(.top, 6)

                Button("Remind me in 10 minutes", action: actions.snooze)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .themedGlass(in: RoundedRectangle(cornerRadius: 36, style: .continuous), palette: palette)
            .frame(maxWidth: 640)

            VStack {
                Spacer()
                SkipHint(action: "snooze")
                    .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
    }
}
