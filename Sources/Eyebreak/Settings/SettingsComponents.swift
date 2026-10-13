import SwiftUI

// MARK: - Page
/// A native grouped form laid over the window's frosted backdrop. The pane name shows
/// in the title bar, as in System Settings.
struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(title)
    }
}

// MARK: - Rows
/// Toggle with an optional secondary line under its title.
struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Slider bound to an Int, with its formatted value to the right.
struct SliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let format: (Int) -> String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int(($0 / Double(step)).rounded()) * step }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound)
                )
                .labelsHidden()
                .frame(minWidth: 160, maxWidth: 240)
                .accessibilityLabel(title)
                .accessibilityValue(format(value))

                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 86, alignment: .trailing)
            }
        }
    }
}

// MARK: - Formatting
enum SettingsFormat {
    static func minutes(_ value: Int) -> String { value == 1 ? "1 minute" : "\(value) minutes" }

    static func seconds(_ value: Int) -> String {
        if value >= 60 {
            let m = value / 60, s = value % 60
            return s == 0 ? "\(m) min" : "\(m) min \(s) s"
        }
        return value == 1 ? "1 second" : "\(value) seconds"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total >= 3600 { return "\(total / 3600) h \((total % 3600) / 60) min" }
        if total >= 60 { return total % 60 == 0 ? "\(total / 60) min" : "\(total / 60) min \(total % 60) s" }
        return "\(total) s"
    }
}
