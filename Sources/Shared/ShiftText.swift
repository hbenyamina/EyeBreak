import Foundation

/// The words and countdowns for the shift, shared by the menu bar, the popover, Settings
/// and the tests. Foundation only, so the tests can compile it.
enum ShiftText {
    /// "3:24:11", or "2d 4h" when the next shift is days away.
    static func long(until target: Date?, from now: Date) -> String {
        guard let target else { return "—" }
        let seconds = max(0, Int(target.timeIntervalSince(now)))
        if seconds >= 86_400 {
            return String(shared: "\(seconds / 86_400)d \((seconds % 86_400) / 3600)h")
        }
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60).localizedDigits
    }

    /// Short enough for the menu bar: "3:24", "24m", "45s", or "Off".
    static func short(for status: ShiftStatus?, now: Date) -> String {
        guard let status else { return "—" }
        let seconds = max(0, Int(status.target.timeIntervalSince(now)))
        if status.phase == .offDuty && seconds > 12 * 3600 { return String(shared: "Off") }
        if seconds >= 3600 { return String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60).localizedDigits }
        if seconds >= 60 { return String(shared: "\((seconds % 3600) / 60)m") }
        return String(shared: "\(seconds)s")
    }

    static func symbol(for status: ShiftStatus?) -> String {
        switch status?.phase {
        case .onShift: return "hourglass"
        case .beforeShift: return "sunrise.fill"
        case .offDuty: return "moon.zzz.fill"
        case .none: return "calendar.badge.exclamationmark"
        }
    }

    static func headline(for status: ShiftStatus?) -> String {
        guard let status else { return String(shared: "Pick at least one day") }
        switch status.phase {
        case .onShift: return String(shared: "Left in your shift")
        case .beforeShift: return String(shared: "Until your shift starts")
        case .offDuty: return String(shared: "Off the clock · next shift in")
        }
    }

    /// Spoken form of the menu bar countdown.
    static func accessibilityPhrase(for status: ShiftStatus?) -> String {
        guard let status else { return String(shared: "no shift days picked") }
        switch status.phase {
        case .onShift: return String(shared: "until the end of your shift")
        case .beforeShift: return String(shared: "until your shift starts")
        case .offDuty: return String(shared: "until your next shift")
        }
    }
}
