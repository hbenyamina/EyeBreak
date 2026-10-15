import SwiftUI

// The window's page grammar, in the Notion/TickTick manner: an opaque paper page with a
// large title, sections set by a heading over a hairline, and flat rows — a title and one
// line of description on the left, a native control on the right. No boxed groups; the
// type and the spacing do the grouping. Each page shows a few essentials; the rest waits
// under "More options".
//
// Titles are `LocalizedStringKey`, so a literal is looked up in the string catalog. Text
// that's already localized (built with `String(localized:)`) goes in as `.verbatim(_:)`.

extension LocalizedStringKey {
    /// Already-localized text, shown as it is.
    static func verbatim(_ text: String) -> LocalizedStringKey { "\(text)" }
}

// MARK: - Page
struct SettingsPage<Content: View>: View {
    let pane: SettingsPane
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(pane: pane)
                content()
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.top, 34)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Page.paper)
        .tint(pane.tint)
        .toggleStyle(.switch)
    }
}

/// The page's symbol, its title, and the question it answers.
struct PageHeader: View {
    let pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: pane.icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(pane.tint)
                .frame(height: 34, alignment: .bottomLeading)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            Text(pane.title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Theme.Page.ink)
                .accessibilityAddTraits(.isHeader)
            Text(pane.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Page.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Section
/// A heading over a hairline, its rows, and an optional note underneath.
struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Page.ink)
                .padding(.bottom, 7)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Theme.Page.hairline)
                .frame(height: 1)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Page.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 30)
    }
}

// MARK: - More Options
/// Everything past a page's essentials, folded away until asked for.
struct MoreOptions<Content: View>: View {
    @ViewBuilder let content: () -> Content
    #if DEBUG
    // `-expandMoreOptions YES` opens every page's extras, for checking them
    @State private var isOpen = UserDefaults.standard.bool(forKey: "expandMoreOptions")
    #else
    @State private var isOpen = false
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(isOpen ? "Fewer options" : "More options")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Spacer()
                }
                .foregroundStyle(Theme.Page.secondaryInk)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 26)
            .accessibilityValue(Text(isOpen ? "Shown" : "Hidden"))

            if isOpen {
                content()
            }
        }
    }
}

// MARK: - Rows
/// Title and optional description on the left, the control on the right.
struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Page.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Page.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.vertical, 9)
        .frame(minHeight: 40)
    }
}

/// A switch row.
struct ToggleRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, detail: subtitle) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

/// A slider bound to an Int, with its formatted value beside it.
struct SliderRow: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let format: (Int) -> String

    var body: some View {
        SettingRow(title: title, detail: detail) {
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int(($0 / Double(step)).rounded()) * step }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound)
                )
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 170)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(format(value)))

                Text(format(value))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Page.secondaryInk)
                    .frame(width: 84, alignment: .trailing)
            }
        }
    }
}

/// A pop-up menu row.
struct PickerRow<Value: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        SettingRow(title: title, detail: detail) {
            Picker(title, selection: $selection, content: options)
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// A stepper with its value spelled out to its left.
struct StepperRow: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    let valueText: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        SettingRow(title: title, detail: detail) {
            HStack(spacing: 8) {
                Text(valueText)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Page.secondaryInk)
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
    }
}

/// A button on the right of a row, for "Preview" and "Show now" actions.
struct ActionRow: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    let button: LocalizedStringKey
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        SettingRow(title: title, detail: detail) {
            Button(button, role: role, action: action)
                .controlSize(.small)
        }
    }
}

/// A plain label and value, for read-only facts.
struct ValueRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        SettingRow(title: title) {
            Text(value)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Theme.Page.secondaryInk)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Callout
/// A Notion-style callout: a quiet tinted block with a symbol, for the one thing on a page
/// worth reading first.
struct Callout<Accessory: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var tint: Color = Theme.onPage
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 20)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Page.ink)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Page.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.Page.wash))
        .padding(.top, 24)
    }
}

extension Callout where Accessory == EmptyView {
    init(icon: String, title: LocalizedStringKey, message: LocalizedStringKey, tint: Color = Theme.onPage) {
        self.init(icon: icon, title: title, message: message, tint: tint) { EmptyView() }
    }
}

// MARK: - Formatting
enum SettingsFormat {
    static func minutes(_ value: Int) -> String {
        value == 1 ? String(localized: "1 minute") : String(localized: "\(value) minutes")
    }

    static func seconds(_ value: Int) -> String {
        if value >= 60 {
            let m = value / 60, s = value % 60
            return s == 0 ? String(localized: "\(m) min") : String(localized: "\(m) min \(s) s")
        }
        return value == 1 ? String(localized: "1 second") : String(localized: "\(value) seconds")
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total >= 3600 { return String(localized: "\(total / 3600) h \((total % 3600) / 60) min") }
        if total >= 60 { return total % 60 == 0 ? String(localized: "\(total / 60) min") : String(localized: "\(total / 60) min \(total % 60) s") }
        return String(localized: "\(total) s")
    }
}
