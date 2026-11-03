import Darwin
import Foundation

/// Everything the app shares with the End of Shift widget: the hours and the widget theme.
struct ShiftSettings: Codable, Hashable {
    var schedule: ShiftSchedule
    var themeID: String

    static let standard = ShiftSettings(schedule: .standard, themeID: ShiftTheme.defaultID)

    init(schedule: ShiftSchedule, themeID: String) {
        self.schedule = schedule
        self.themeID = themeID
    }

    private enum CodingKeys: String, CodingKey {
        case schedule, themeID
    }

    /// Shift Countdown files written before it had themes hold the schedule's keys at the
    /// top level; they still load, with the default theme.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let schedule = try container.decodeIfPresent(ShiftSchedule.self, forKey: .schedule) {
            self.schedule = schedule
            self.themeID = try container.decodeIfPresent(String.self, forKey: .themeID) ?? ShiftTheme.defaultID
        } else {
            self.schedule = try ShiftSchedule(from: decoder)
            self.themeID = ShiftTheme.defaultID
        }
    }
}

/// The shift settings as a small JSON file at
/// `~/Library/Application Support/EyeBreak/shift.json`, written by the app on every edit
/// and read by the widget whenever it builds a timeline.
///
/// Not an app group container: with no team ID to prefix the group with, a widget
/// extension's sandbox denies the group container even with the entitlement present.
/// The widget stays sandboxed — macOS won't host an unsandboxed widget extension — and
/// reads this one path through a read-only sandbox exception in its entitlements. The
/// app itself isn't sandboxed, so it writes here directly. With a real signing identity,
/// an app group is the tidier home for this.
enum ShiftStore {
    static let directoryName = "EyeBreak"
    static let fileName = "shift.json"

    /// Where Shift Countdown kept the same settings before it became part of EyeBreak.
    static let legacyDirectoryName = "ShiftCountdown"
    static let legacyFileName = "working-hours.json"

    /// The user's real home, which stays correct inside the widget's sandbox — where
    /// `FileManager.homeDirectoryForCurrentUser` would hand back the container instead.
    private static var realHome: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func applicationSupport(_ directory: String) -> URL {
        realHome
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directory, isDirectory: true)
    }

    /// `~/Library/Application Support/EyeBreak`, shared by every build and bundle ID. A
    /// debug build launched with `EYEBREAK_SUPPORT_DIR` keeps its files there instead, so a
    /// test run can't touch the installed app's shift or day.
    static var directoryURL: URL {
        #if DEBUG
        if let folder = ProcessInfo.processInfo.environment["EYEBREAK_SUPPORT_DIR"], !folder.isEmpty {
            return URL(fileURLWithPath: folder, isDirectory: true)
        }
        #endif
        return applicationSupport(directoryName)
    }

    static var fileURL: URL { directoryURL.appendingPathComponent(fileName) }
    static var legacyFileURL: URL { applicationSupport(legacyDirectoryName).appendingPathComponent(legacyFileName) }

    static var exists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    /// Falls back to a 9-to-5, Monday to Friday, in the default theme if nothing has been
    /// saved yet or the file is unreadable.
    static func load() -> ShiftSettings {
        load(from: fileURL) ?? .standard
    }

    /// Shift Countdown's file, if it's still there.
    static func loadLegacy() -> ShiftSettings? {
        load(from: legacyFileURL)
    }

    private static func load(from url: URL) -> ShiftSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ShiftSettings.self, from: data)
    }

    static func save(_ settings: ShiftSettings) {
        let url = fileURL
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// For diagnostics in the widget's log.
    static func describeFile() -> String {
        let url = fileURL
        do {
            let data = try Data(contentsOf: url)
            return String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
        } catch {
            return "READ FAILED err=\(error) path=\(url.path)"
        }
    }
}

extension ShiftSchedule {
    /// The shift EyeBreak's older hour-only Smart Schedule described: whole hours, a set
    /// of weekdays, and equal start and end meaning around the clock.
    static func fromWorkHours(start: Int, end: Int, days: Set<Int>) -> ShiftSchedule {
        ShiftSchedule(startHour: min(max(start, 0), 23), startMinute: 0,
                      endHour: min(max(end, 0), 23), endMinute: 0,
                      weekdays: days.filter { (1...7).contains($0) })
    }
}
