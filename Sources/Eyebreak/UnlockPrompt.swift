import AppKit
import SwiftUI
import OSLog
import UserNotifications

private let log = Logger(subsystem: "com.eyebreak.app", category: "prompt")

/// Asks whether today's shift should start from the moment the Mac was unlocked — for
/// the days you arrive late and want the countdown (and the Smart Schedule) to run from
/// when you actually sat down.
///
/// It listens for the screen unlocking and for the app's own launch (which covers
/// login), and asks only while a shift is due or already running. One question per
/// shift: "No" mutes it until the scheduled start if that hasn't come yet, otherwise
/// until the shift ends; "Yes" sets the start and the question doesn't come back that
/// day. A notification that is merely cleared counts as unanswered, so the next unlock
/// asks again.
///
/// The question is a system notification when macOS allows one, and otherwise a glass
/// toast of the same shape — an ad-hoc signed build gets the toast, because the
/// notification daemon refuses an identity that is only a cdhash.
final class UnlockPrompt: NSObject, ObservableObject {
    /// True when macOS reports notifications turned off for this app, so Settings can say
    /// why the question arrives as a toast.
    @Published private(set) var notificationsDenied = false

    /// Clicking the notification itself: neither answer, so show the shift settings.
    var onOpenSettings: (() -> Void)?

    private let settings: AppSettings
    private let shift: ShiftModel
    private var toast: NSWindow?
    private var observers: [NSObjectProtocol] = []

    private static let categoryID = "shift-start"
    private static let startActionID = "start-now"
    private static let skipActionID = "not-now"
    private static let requestID = "shift-start-prompt"
    private static let momentKey = "moment"
    /// Shift Countdown's key, kept so the two never disagree about a "No".
    private static let mutedUntilKey = "shiftStartPromptMutedUntil"

    init(settings: AppSettings = .shared, shift: ShiftModel) {
        self.settings = settings
        self.shift = shift
        super.init()
    }

    deinit {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
    }

    /// Call before the app finishes launching: a click on the notification can be what
    /// launched the app, and that response only reaches a delegate already in place.
    func activate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let start = UNNotificationAction(identifier: Self.startActionID, title: String(localized: "Yes, start now"))
        let skip = UNNotificationAction(identifier: Self.skipActionID, title: String(localized: "No"))
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: [start, skip], intentIdentifiers: []),
        ])
    }

    /// Starts listening. Launch counts as an unlock — it's how a login reaches here — so
    /// this also asks.
    func start() {
        // Screen unlock has no public API; loginwindow posts this distributed
        // notification when the lock screen goes away.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.consider() })
        // Coming back to this account after a fast user switch.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.consider() })

        consider()
    }

    // MARK: - Asking

    private var mutedUntil: Date? {
        get {
            let stamp = UserDefaults.standard.double(forKey: Self.mutedUntilKey)
            return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Self.mutedUntilKey)
        }
    }

    /// Asks if this is a moment worth asking about.
    func consider(now: Date = Date()) {
        guard settings.askOnUnlock else { log.notice("skip: asking is turned off"); return }
        let schedule = shift.schedule
        // Only while a shift is due today or already running — not on a day off, and not
        // once today's shift is over.
        guard let status = schedule.status(at: now), status.phase != .offDuty else {
            log.notice("skip: off duty")
            return
        }
        // Already started from an unlock: nothing to ask.
        guard schedule.adjustedStart != status.window.start else { log.notice("skip: already started from now"); return }
        if let mutedUntil, now < mutedUntil {
            log.notice("skip: answered No, muted until \(mutedUntil, privacy: .public)")
            return
        }
        guard let question = Self.question(for: status, schedule: schedule, at: now) else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationsDenied = !granted
                if granted {
                    self.post(question, at: now)
                } else {
                    // Refused without asking the user: the usual case for an ad-hoc signed
                    // build. The toast asks the same question in the same place.
                    log.notice("notifications not allowed (\(error?.localizedDescription ?? "denied", privacy: .public)); showing the toast instead")
                    self.showToast(question, at: now)
                }
            }
        }
    }

    private static func question(for status: ShiftStatus, schedule: ShiftSchedule, at moment: Date) -> (title: String, body: String)? {
        var adjusted = schedule
        adjusted.adjustedStart = moment
        guard let window = adjusted.adjustedWindow() else { return nil }
        return (String(localized: "Start your shift from now?"),
                String(localized: "It's \(schedule.clockText(for: moment)). Yes makes today's shift \(schedule.rangeText(for: window)) instead of \(schedule.rangeText(for: status.window))."))
    }

    #if DEBUG
    /// The toast as it would appear right now, without asking macOS for notifications.
    func previewToast() {
        let now = Date()
        guard let status = shift.schedule.status(at: now),
              let question = Self.question(for: status, schedule: shift.schedule, at: now) else { return }
        showToast(question, at: now)
    }
    #endif

    private func showToast(_ question: (title: String, body: String), at moment: Date) {
        dismissToast()
        let view = ShiftPromptView(title: question.title, message: question.body) { [weak self] answer in
            self?.dismissToast()
            switch answer {
            case true?: self?.handle(action: Self.startActionID, moment: moment)
            case false?: self?.handle(action: Self.skipActionID, moment: moment)
            case nil: log.notice("toast closed without an answer")
            }
        }
        toast = ToastWindow.show(view, position: .topRight)
        log.notice("asked (toast): \(question.body, privacy: .public)")
    }

    private func dismissToast() {
        guard let toast else { return }
        self.toast = nil
        ToastWindow.fadeOut(toast)
    }

    private func post(_ question: (title: String, body: String), at moment: Date) {
        let content = UNMutableNotificationContent()
        content.title = question.title
        content.body = question.body
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [Self.momentKey: moment.timeIntervalSince1970]

        // A fixed identifier: a second unlock before the first question was answered
        // replaces it rather than stacking another.
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("could not post: \(error.localizedDescription, privacy: .public)")
            } else {
                log.notice("asked: \(content.body, privacy: .public)")
            }
        }
    }

    // MARK: - Answers

    private func handle(action: String, moment: Date?) {
        log.notice("answer: \(action, privacy: .public)")
        switch action {
        case Self.startActionID:
            shift.startShift(at: moment ?? Date())
        case Self.skipActionID:
            // Said before the shift is due: ask again once it is. Said after: that's the
            // answer for this shift.
            let now = Date()
            if let window = shift.schedule.status(at: now)?.window {
                mutedUntil = now < window.start ? window.start : window.end
            } else {
                mutedUntil = now.addingTimeInterval(12 * 3600)
            }
        case UNNotificationDefaultActionIdentifier:
            onOpenSettings?()
        default:
            break
        }
    }
}

extension UnlockPrompt: UNUserNotificationCenterDelegate {
    /// Show it even when the app is frontmost (the break notifications too).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        // The "Notification Only" break notifications share this delegate; they need nothing.
        guard content.categoryIdentifier == Self.categoryID else { return completionHandler() }
        let action = response.actionIdentifier
        let moment = (content.userInfo[Self.momentKey] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        DispatchQueue.main.async {
            self.handle(action: action, moment: moment)
            completionHandler()
        }
    }
}

// MARK: - Toast
/// The question as a glass toast at the top right, where a notification banner would
/// sit, with both answers in plain sight rather than behind a hover menu.
private struct ShiftPromptView: View {
    let title: String
    let message: String
    let answer: (Bool?) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Yes, start now") { answer(true) }
                        .buttonStyle(AccentButtonStyle())
                    Button("No") { answer(false) }
                        .buttonStyle(SoftButtonStyle())
                }
                .padding(.top, 6)
            }

            Spacer(minLength: 0)

            GlassCloseButton(label: String(localized: "Ask again at the next unlock")) { answer(nil) }
        }
        .padding(14)
        .frame(width: 372)
        .glassSurface(in: RoundedRectangle(cornerRadius: 22, style: .continuous), tint: Theme.accent.opacity(0.08), frosted: true)
    }
}
