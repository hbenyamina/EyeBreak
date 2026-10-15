import AppKit
import UserNotifications

// MARK: - Sounds
enum SoundEffect: String {
    case warning = "Tink"
    case breakStart = "Glass"
    case breakEnd = "Hero"
    case water = "Bottle"

    var volume: Float {
        switch self {
        case .warning: return 0.35
        default: return 0.6
        }
    }
}

enum SoundManager {
    static func play(_ effect: SoundEffect) {
        guard AppSettings.shared.soundEffectsEnabled, let sound = NSSound(named: effect.rawValue) else { return }
        sound.volume = effect.volume
        sound.play()
    }
}

// MARK: - Notifications
/// Used by the "Notification Only" break style.
enum NotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if AppSettings.shared.soundEffectsEnabled {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func postBreakStart(duration: TimeInterval, isLong: Bool) {
        if isLong {
            post(title: String(localized: "Time for a long break"),
                 body: String(localized: "Stand up, refill your water and look out of a window."))
        } else {
            post(title: String(localized: "Time for a break"),
                 body: String(localized: "Look across the room for \(Int(duration)) seconds, then blink slowly twice."))
        }
    }

    static func postBreakComplete() {
        post(title: String(localized: "Break done"), body: String(localized: "Back to it."))
    }
}
