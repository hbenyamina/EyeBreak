import Combine
import SwiftUI

/// Water: how you're keeping up, then the goal, the glass and when you're asked. The goal
/// calculator and the reminder's look wait under their own disclosures.
struct WaterSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var activity: ActivityModel
    @ObservedObject var shift: ShiftModel
    let showWaterNow: () -> Void

    @State private var now = Date()
    @State private var calculatorOpen = false
    private let minute = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let iconColumns = Array(repeating: GridItem(.fixed(34), spacing: 6), count: 6)

    private var unit: WaterUnit { settings.waterUnit }
    private func amount(_ ml: Int) -> String { WaterAmount.text(ml, unit: unit) }

    var body: some View {
        SettingsPage(pane: .water) {
            SettingsSection(title: "Your rhythm", footer: "Straight while you keep pace with your goal; it dips when you fall a glass behind. Water, tea and coffee all count.") {
                HabitRhythm(habit: .water, activity: activity, now: now,
                            value: WaterAmount.progress(activity.log.waterML(on: now), of: settings.waterGoalML, unit: unit))
            }

            SettingsSection(title: "Water") {
                ToggleRow(title: "Remind me to drink", isOn: $settings.waterReminderEnabled)
                goalRow
                PickerRow(title: "My glass", detail: "What one \"I Drank\" adds.", selection: $settings.glassSizeML) {
                    ForEach(glassOptions, id: \.self) { ml in
                        Text(verbatim: amount(ml)).tag(ml)
                    }
                }
                if settings.waterReminderEnabled {
                    PickerRow(title: "Ask me", detail: .verbatim(modeDetail), selection: $settings.waterReminderMode) {
                        ForEach(WaterReminderMode.allCases) { Text(verbatim: $0.label).tag($0) }
                    }
                    if !settings.waterRidesWithBreaks {
                        SliderRow(title: "Every", detail: .verbatim(paceText),
                                  value: $settings.waterReminderInterval,
                                  range: WaterGoal.minimumInterval(glass: settings.glassSizeML)...180, step: 5,
                                  format: SettingsFormat.minutes)
                    }
                }
            }
            .environment(\.palette, .water)

            calculator

            MoreOptions {
                SettingsSection(title: "Units") {
                    PickerRow(title: "Show amounts in", selection: $settings.waterUnit) {
                        ForEach(WaterUnit.allCases) { Text(verbatim: $0.label).tag($0) }
                    }
                }
                if settings.waterReminderEnabled {
                    reminderLook
                }
            }
        }
        .tint(Theme.Water.deep)
        .onReceive(minute) { now = $0 }
    }

    // MARK: - Goal
    private var goalRow: some View {
        SettingRow(title: "Drink each day", detail: .verbatim(glassesText(settings.waterGoalML))) {
            HStack(spacing: 8) {
                Text(verbatim: amount(settings.waterGoalML))
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Page.ink)
                Stepper("Drink each day") {
                    stepGoal(by: 1)
                } onDecrement: {
                    stepGoal(by: -1)
                }
                .labelsHidden()
            }
        }
    }

    private var modeDetail: String {
        if settings.waterReminderMode == .withBreaks && settings.longBreakEvery == 0 {
            return String(localized: "Long breaks are off in Breaks, so water keeps its own timer.")
        }
        return settings.waterReminderMode.detail
    }

    /// "To drink 2 L over your 8h shift, about every 60 minutes."
    private var paceText: String {
        let pace = WaterGoal.reminderInterval(goal: settings.waterGoalML, glass: settings.glassSizeML, over: shift.schedule.durationMinutes)
        return String(localized: "To drink \(amount(settings.waterGoalML)) over a \(shift.schedule.durationText) shift, about every \(pace) minutes. Never closer than \(WaterGoal.minimumInterval(glass: settings.glassSizeML)) minutes for this glass.")
    }

    /// "About 8 glasses of 250 ml."
    private func glassesText(_ goal: Int) -> String {
        let glasses = Int((Double(goal) / Double(max(settings.glassSizeML, 1))).rounded())
        return String(localized: "About \(glasses) glasses of \(amount(settings.glassSizeML)).")
    }

    /// 100 ml at a time, or 4 fl oz.
    private func stepGoal(by direction: Int) {
        let step = unit == .milliliters ? 100 : WaterAmount.milliliters(fluidOunces: 4)
        let next = settings.waterGoalML + direction * step
        let snapped = unit == .milliliters ? Int((Double(next) / 100).rounded()) * 100 : next
        settings.waterGoalML = min(max(snapped, 500), 6000)
    }

    /// Common glass and bottle sizes up to half a litre, plus whatever is set now.
    private var glassOptions: [Int] {
        let common = unit == .milliliters
            ? [150, 200, 250, 300, 330, 400, 500]
            : [6, 8, 10, 12, 16].map { WaterAmount.milliliters(fluidOunces: Double($0)) }
        return Array(Set(common + [settings.glassSizeML])).sorted()
    }

    // MARK: - Calculator
    private var calculator: some View {
        let suggested = WaterGoal.estimate(weightKg: settings.bodyWeightKg, sex: settings.waterSex,
                                           exerciseMinutes: settings.activeMinutesPerDay,
                                           intensity: settings.exerciseIntensity, hot: settings.hotClimate)
        let hasWeight = settings.bodyWeightKg > 0

        return VStack(alignment: .leading, spacing: 0) {
            DisclosureRow(title: "Work out my goal", isOpen: $calculatorOpen)
            if calculatorOpen {
                SettingsSection(
                    title: "About you",
                    footer: "Drinks only: food brings another fifth or so. Based on EFSA's intakes as drinks (1.6 L for women, 2.0 L for men), about 10 ml more per kilo above a reference weight, more for exercise, and 500 ml in the heat. An estimate for healthy adults, not medical advice: pregnancy, breastfeeding, and kidney or heart conditions change what's right, so ask your doctor."
                ) {
                    PickerRow(title: "Body", selection: $settings.waterSex) {
                        ForEach(WaterSex.allCases) { Text(verbatim: $0.label).tag($0) }
                    }
                    SettingRow(title: "Weight") {
                        HStack(spacing: 6) {
                            TextField("Weight", value: weightBinding, format: .number.precision(.fractionLength(0)))
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                            Text(unit == .milliliters ? "kg" : "lb")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Page.secondaryInk)
                                .frame(width: 22, alignment: .leading)
                        }
                    }
                    StepperRow(
                        title: "Exercise on a typical day",
                        detail: "Deliberate exercise, not walking about the office.",
                        valueText: settings.activeMinutesPerDay == 0 ? String(localized: "None") : String(localized: "\(settings.activeMinutesPerDay) min"),
                        value: $settings.activeMinutesPerDay,
                        range: 0...240,
                        step: 15
                    )
                    if settings.activeMinutesPerDay > 0 {
                        PickerRow(title: "How hard", detail: .verbatim(settings.exerciseIntensity.detail), selection: $settings.exerciseIntensity) {
                            ForEach(ExerciseIntensity.allCases) { Text(verbatim: $0.label).tag($0) }
                        }
                    }
                    ToggleRow(title: "Hot, without air conditioning", isOn: $settings.hotClimate)
                    SettingRow(
                        title: hasWeight ? .verbatim(String(localized: "Suggested: \(amount(suggested))")) : "Suggested",
                        detail: hasWeight ? .verbatim(glassesText(suggested)) : "Enter your weight to get an estimate."
                    ) {
                        Button(suggested == settings.waterGoalML ? "In Use" : "Use This Goal") {
                            settings.waterGoalML = suggested
                        }
                        .controlSize(.small)
                        .disabled(!hasWeight || suggested == settings.waterGoalML)
                    }
                }
            }
        }
    }

    /// Weight in kilograms, shown in pounds where water is in fluid ounces.
    private var weightBinding: Binding<Double> {
        Binding(
            get: {
                let kg = settings.bodyWeightKg
                return unit == .milliliters ? kg : (kg * 2.20462).rounded()
            },
            set: { value in
                let kg = unit == .milliliters ? value : value / 2.20462
                settings.bodyWeightKg = min(max(kg, 0), 300)
            }
        )
    }

    // MARK: - Reminder look
    private var reminderLook: some View {
        SettingsSection(title: "The reminder") {
            PickerRow(title: "Shows as", detail: .verbatim(settings.waterReminderStyle.detail), selection: $settings.waterReminderStyle) {
                ForEach(WaterReminderStyle.allCases) { Text(verbatim: $0.label).tag($0) }
            }
            ToggleRow(title: "My own icon and message", isOn: $settings.useCustomWaterReminder)

            if settings.useCustomWaterReminder {
                SettingRow(title: "Icon") {
                    LazyVGrid(columns: iconColumns, alignment: .trailing, spacing: 6) {
                        ForEach(WaterReminderManager.iconOptions, id: \.symbol) { option in
                            IconOptionButton(
                                symbol: option.symbol,
                                name: option.name,
                                isSelected: settings.customWaterReminderIcon == option.symbol
                            ) {
                                settings.customWaterReminderIcon = option.symbol
                            }
                        }
                    }
                    .frame(width: 234)
                }
                SettingRow(title: "Message") {
                    TextField("Message", text: $settings.customWaterReminderMessage, prompt: Text("Time for a glass of water"))
                        .labelsHidden()
                        .frame(width: 240)
                }
            }
            ActionRow(title: "See a water reminder", button: "Show Now", action: showWaterNow)
        }
        .environment(\.palette, .water)
    }
}

/// A heading that opens a section in place, for a tool most visits don't need.
struct DisclosureRow: View {
    let title: LocalizedStringKey
    @Binding var isOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
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
    }
}

// MARK: - Icon Option
private struct IconOptionButton: View {
    let symbol: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? palette.onFill : Theme.Page.secondaryInk)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? palette.fill : Theme.Page.wash)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: name))
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
