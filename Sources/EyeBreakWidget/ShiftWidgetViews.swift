import SwiftUI
import WidgetKit

struct ShiftEntry: TimelineEntry {
    let date: Date
    let label: String
    let schedule: ShiftSchedule
    let theme: ShiftTheme
    let status: ShiftStatus?
}

// MARK: - Words for each state

private struct Copy {
    let symbol: String
    let title: String
    let unit: String
    let footer: String
    let showsProgress: Bool

    // The right-hand column of the medium widget.
    let asideTitle: String
    let asideValue: String
    let asideDetail: String

    init(entry: ShiftEntry, status: ShiftStatus) {
        let schedule = entry.schedule
        // The window's own ends, not the standing hours: on a day the shift was started
        // from an unlock they differ, and the widget should agree with the countdown.
        let starts = schedule.clockText(for: status.window.start)
        let ends = schedule.clockText(for: status.window.end)
        switch status.phase {
        case .onShift:
            symbol = "hourglass"
            title = entry.label
            unit = String(shared: "left")
            footer = String(shared: "Ends \(ends) · \(schedule.daysText())")
            showsProgress = true
            asideTitle = String(shared: "Ends")
            asideValue = ends
            asideDetail = String(shared: "from \(starts)")
        case .beforeShift:
            symbol = "sunrise.fill"
            title = String(shared: "Your shift starts in")
            unit = String(shared: "at \(starts)")
            footer = String(shared: "\(starts) – \(ends) today")
            showsProgress = false
            asideTitle = String(shared: "Starts")
            asideValue = starts
            asideDetail = String(shared: "ends \(ends)")
        case .offDuty:
            symbol = "moon.zzz.fill"
            title = String(shared: "Off the clock")
            unit = String(shared: "until your next shift")
            footer = "\(status.window.start.weekdayText().capitalized) \(starts) – \(ends)"
            showsProgress = false
            asideTitle = String(shared: "Next")
            asideValue = status.window.start.weekdayText().capitalized
            asideDetail = "\(starts) – \(ends)"
        }
    }
}

/// The theme's solid surface in full colour. When the desktop is set to tinted or clear
/// widgets the system supplies the material and the tint, so the widget steps back to
/// neutral ink and lets `widgetAccentable` mark what should take the colour.
private struct Look {
    let isFullColor: Bool
    let surface: ShiftTheme.Surface

    var ink: Color { isFullColor ? surface.ink : Color.primary }
    /// Solid, not a translucent ink: the contrast floors are computed for these exact
    /// colours on the surface.
    var secondary: Color { isFullColor ? surface.inkSoft : Color.secondary }
    var tertiary: Color { isFullColor ? surface.inkFaint : Color.secondary }
    var track: Color { isFullColor ? surface.track : Color.primary.opacity(0.14) }
}

// MARK: - Pieces

/// The live countdown. Widgets tick `Text(timerInterval:)` themselves, every second,
/// without waking the extension.
private struct Countdown: View {
    let from: Date
    let to: Date
    let size: CGFloat
    let color: Color

    var body: some View {
        let start = min(from, to)
        let end = max(to, start.addingTimeInterval(1))
        Group {
            if end.timeIntervalSince(start) > 12 * 3600 {
                Text(end, style: .relative)
            } else {
                Text(timerInterval: start...end, countsDown: true)
            }
        }
        .font(.system(size: size, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(color)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .widgetAccentable()
    }
}

private struct ShiftProgress: View {
    let fraction: Double
    let fill: Color
    let track: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: max(5, geometry.size.width * fraction))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
    }
}

private struct Header: View {
    let copy: Copy
    let look: Look

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: copy.symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(copy.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(look.secondary)
    }
}

private struct Footer: View {
    let text: String
    let look: Look

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(look.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

// MARK: - Layouts

private struct SmallLayout: View {
    let entry: ShiftEntry
    let status: ShiftStatus
    let look: Look

    var body: some View {
        let copy = Copy(entry: entry, status: status)
        VStack(alignment: .leading, spacing: 0) {
            Header(copy: copy, look: look)
            Spacer(minLength: 4)
            Countdown(from: entry.date, to: status.target, size: 32, color: look.ink)
            Text(copy.unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(look.tertiary)
            Spacer(minLength: 6)
            if copy.showsProgress {
                ShiftProgress(fraction: status.progress(at: entry.date), fill: look.ink, track: look.track)
                    .padding(.bottom, 7)
            }
            Footer(text: copy.footer, look: look)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumLayout: View {
    let entry: ShiftEntry
    let status: ShiftStatus
    let look: Look

    var body: some View {
        let copy = Copy(entry: entry, status: status)
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Header(copy: copy, look: look)
                Spacer(minLength: 4)
                Countdown(from: entry.date, to: status.target, size: 44, color: look.ink)
                Text(copy.unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(look.tertiary)
                // On shift the progress bar closes the column; otherwise the countdown does,
                // so both columns end on the same line
                if copy.showsProgress {
                    Spacer(minLength: 8)
                    ShiftProgress(fraction: status.progress(at: entry.date), fill: look.ink, track: look.track)
                        .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // A hairline, not a card inside a card.
            Rectangle()
                .fill(look.track)
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(copy.asideTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(look.secondary)
                Text(copy.asideValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(look.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(copy.asideDetail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(look.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 6)
                Text(entry.schedule.daysText())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(look.secondary)
                    .lineLimit(1)
                if let zone = entry.schedule.timeZoneText {
                    Text(zone)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(look.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 104, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct NoDaysLayout: View {
    let look: Look

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
            Text(String(shared: "Pick the days you work in EyeBreak Settings → Workday"))
                .font(.system(size: 11, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(look.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Entry point

struct ShiftWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ShiftEntry

    private var look: Look {
        Look(isFullColor: renderingMode == .fullColor,
             surface: entry.theme.surface(for: entry.status?.phase))
    }

    var body: some View {
        let look = self.look
        content(look: look)
            .environment(\.layoutDirection, L10n.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, L10n.locale)
            .containerBackground(for: .widget) {
                if look.isFullColor {
                    look.surface.color
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder private func content(look: Look) -> some View {
        if let status = entry.status {
            if family == .systemMedium {
                MediumLayout(entry: entry, status: status, look: look)
            } else {
                SmallLayout(entry: entry, status: status, look: look)
            }
        } else {
            NoDaysLayout(look: look)
        }
    }
}
