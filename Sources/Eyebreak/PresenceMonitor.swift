import AppKit
import CoreAudio
import CoreGraphics
import CoreMediaIO

/// Watches for the user being away (idle input, locked screen), in a call (camera or
/// microphone in use), and for the shift's hours.
final class PresenceMonitor: ObservableObject {
    @Published private(set) var isIdle = false
    @Published private(set) var isScreenLocked = false
    @Published private(set) var isWithinSchedule = true
    @Published private(set) var isInCall = false

    private let settings: AppSettings
    private let shift: ShiftModel
    private var timer: Timer?

    init(settings: AppSettings = .shared, shift: ShiftModel) {
        self.settings = settings
        self.shift = shift
    }

    deinit {
        timer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)

        evaluate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.evaluate() }
    }

    /// Re-check immediately, e.g. after schedule settings change.
    func evaluate() {
        isWithinSchedule = !settings.smartScheduleEnabled || shift.isOnShift()

        if settings.idleDetectionEnabled {
            let idleSeconds = InputActivity.secondsSinceAnyInput()
            let threshold = TimeInterval(settings.idleThresholdMinutes * 60)
            // Small hysteresis so a single mouse nudge doesn't flap the state
            if !isIdle && idleSeconds >= threshold {
                isIdle = true
            } else if isIdle && idleSeconds < 5 {
                isIdle = false
            }
        } else if isIdle {
            isIdle = false
        }

        let inCall = settings.holdDuringCalls && (CallDetector.cameraInUse() || CallDetector.microphoneInUse())
        if inCall != isInCall { isInCall = inCall }
    }

    @objc private func screenLocked() { isScreenLocked = true }
    @objc private func screenUnlocked() { isScreenLocked = false }
}

/// How recently you used the keyboard and mouse, from the window server.
enum InputActivity {
    static func secondsSinceAnyInput() -> TimeInterval {
        seconds(since: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged, .leftMouseDragged])
    }

    /// Typing and dragging: the moments a break would cut into.
    static func secondsSinceTyping() -> TimeInterval {
        seconds(since: [.keyDown, .leftMouseDragged])
    }

    private static func seconds(since types: [CGEventType]) -> TimeInterval {
        types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? .infinity
    }
}

/// Whether any app is using a camera or the microphone right now: a call, a recording, a
/// meeting. It asks only whether the device is running, never for its picture or sound,
/// so it needs no permission.
enum CallDetector {
    static func microphoneInUse() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != 0 else { return false }

        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }

    static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }

        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return devices.contains { device in
            var running: UInt32 = 0
            var readSize: UInt32 = 0
            guard CMIOObjectGetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &readSize, &running) == noErr else { return false }
            return running != 0
        }
    }
}
