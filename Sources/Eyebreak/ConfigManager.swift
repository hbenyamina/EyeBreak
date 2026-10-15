import Foundation

struct AppConfig: Codable {
    let workDurationMinutes: Int
    let breakDurationSeconds: Int
    let warningTimeSeconds: Int
    let skipsBeforeDryEyeNudge: Int?
    let waterReminderMinutes: Int?

    // Computed properties for TimeInterval values
    var workDuration: TimeInterval {
        TimeInterval(workDurationMinutes * 60)
    }

    var breakDuration: TimeInterval {
        TimeInterval(breakDurationSeconds)
    }

    var warningTime: TimeInterval {
        TimeInterval(warningTimeSeconds)
    }

    var dryEyeNudgeThreshold: Int {
        skipsBeforeDryEyeNudge ?? 2
    }

    /// 0 disables water reminders.
    var waterReminderInterval: TimeInterval {
        TimeInterval(max(waterReminderMinutes ?? 45, 0) * 60)
    }

    // Default fallback values
    static let fallback = AppConfig(
        workDurationMinutes: 20,
        breakDurationSeconds: 30,
        warningTimeSeconds: 0,
        skipsBeforeDryEyeNudge: 2,
        waterReminderMinutes: 60
    )
}

class ConfigManager {
    // MARK: - Singleton
    static let shared = ConfigManager()

    // MARK: - Properties
    let config: AppConfig

    // MARK: - Initialization
    private init() {
        config = ConfigManager.loadConfig()
    }

    // MARK: - Private Methods
    private static func loadConfig() -> AppConfig {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json") else {
            print("config.json not found in bundle, using fallback values")
            return AppConfig.fallback
        }

        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            print("Loaded config: work=\(config.workDurationMinutes)min, break=\(config.breakDurationSeconds)s, warning=\(config.warningTimeSeconds)s")
            return config
        } catch {
            print("Failed to load config: \(error.localizedDescription), using fallback values")
            return AppConfig.fallback
        }
    }
}
