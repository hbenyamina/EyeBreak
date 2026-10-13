import AppKit
import UserNotifications

// MARK: - Sounds
enum SoundEffect: String {
    case warning = "Tink"
    case breakStart = "Glass"
    case breakEnd = "Hero"
    case water = "Bottle"
    case ambient = "Pop"

    var volume: Float {
        switch self {
        case .ambient, .warning: return 0.35
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

    static func postBreakStart(seconds: Int) {
        post(title: "Time for a Break!", body: "Look away! Stare at something 20 feet away for \(seconds) seconds. Your eyes will thank you.")
    }

    static func postBreakComplete() {
        post(title: "Break complete!", body: "Back to work.")
    }
}
