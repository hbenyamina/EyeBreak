import AppIntents
import Foundation

/// The only thing a widget carries of its own is its label. The hours, days and time
/// zone always come from EyeBreak, through the shared file — so the widget and the app
/// can never disagree.
///
/// Kept deliberately small: every parameter here is a value macOS has to decode from a
/// widget placed by an older build, and one it can't decode leaves the widget frozen on
/// its last drawing.
struct EndOfShiftConfiguration: WidgetConfigurationIntent {

    static var title: LocalizedStringResource = "End of Shift"
    static var description = IntentDescription("Counts down to the end of your shift. Set the hours in EyeBreak Settings → Workday.")

    @Parameter(title: "Label", default: "End of shift")
    var label: String

    static var parameterSummary: some ParameterSummary {
        Summary("Count down to the end of \(\.$label)")
    }

    /// The label until you write your own, in the app's language.
    static var defaultLabel: String { String(shared: "End of shift") }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "End of shift" ? Self.defaultLabel : trimmed
    }
}
