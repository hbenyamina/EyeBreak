import OSLog
import SwiftUI
import WidgetKit

private let log = Logger(subsystem: "com.eyebreak.app", category: "widget")

struct EndOfShiftProvider: AppIntentTimelineProvider {
    typealias Entry = ShiftEntry
    typealias Intent = EndOfShiftConfiguration

    func placeholder(in context: Context) -> ShiftEntry {
        L10n.follow(language: ActivityStore.load().language)
        return entry(at: Date(), label: EndOfShiftConfiguration.defaultLabel, settings: ShiftStore.load())
    }

    func snapshot(for configuration: EndOfShiftConfiguration, in context: Context) async -> ShiftEntry {
        // The app's language and theme come from the activity file
        L10n.follow(language: ActivityStore.load().language)
        let settings = ShiftStore.load()
        log.notice("snapshot: hours=\(settings.schedule.summaryText(), privacy: .public)")
        return entry(at: Date(), label: configuration.displayLabel, settings: settings)
    }

    func timeline(for configuration: EndOfShiftConfiguration, in context: Context) async -> Timeline<ShiftEntry> {
        L10n.follow(language: ActivityStore.load().language)
        let now = Date()
        let settings = ShiftStore.load()
        let label = configuration.displayLabel
        log.notice("timeline: hours=\(settings.schedule.summaryText(), privacy: .public) theme=\(settings.themeID, privacy: .public) store=\(ShiftStore.describeFile(), privacy: .public)")

        // The countdown text ticks by itself, so entries only need to cover the state
        // changes — shift start, shift end — and the progress bar's steps.
        let entries = settings.schedule.timelineDates(from: now).map {
            entry(at: $0, label: label, settings: settings)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(at date: Date, label: String, settings: ShiftSettings) -> ShiftEntry {
        ShiftEntry(date: date,
                   label: label,
                   schedule: settings.schedule,
                   theme: ShiftTheme.named(settings.themeID),
                   status: settings.schedule.status(at: date))
    }
}

struct EndOfShiftWidget: Widget {
    /// Stable: changing it orphans every widget already on someone's desktop.
    static let kind = "EndOfShiftWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind,
                               intent: EndOfShiftConfiguration.self,
                               provider: EndOfShiftProvider()) { entry in
            ShiftWidgetView(entry: entry)
                .widgetURL(URL(string: "eyebreak://shift"))
        }
        .configurationDisplayName("End of Shift")
        .description("Counts down to the end of your shift. Set the hours in EyeBreak Settings → Workday.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct EyeBreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        RhythmWidget()
        EndOfShiftWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    EndOfShiftWidget()
} timeline: {
    let schedule = ShiftSchedule.standard
    ShiftEntry(date: Date(), label: "End of shift", schedule: schedule, theme: .slate, status: schedule.status(at: Date()))
}

#Preview("Medium", as: .systemMedium) {
    EndOfShiftWidget()
} timeline: {
    let schedule = ShiftSchedule.standard
    ShiftEntry(date: Date(), label: "End of shift", schedule: schedule, theme: .slate, status: schedule.status(at: Date()))
}
