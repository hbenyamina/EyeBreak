import Foundation

/// How amounts of water are shown. Stored amounts are always millilitres.
enum WaterUnit: String, CaseIterable, Codable, Identifiable {
    case milliliters
    case fluidOunces

    var id: String { rawValue }
    var label: String { self == .milliliters ? String(shared: "Millilitres") : String(shared: "Fluid Ounces") }

    /// US customary measurement gets ounces; everywhere else, millilitres.
    static var regionDefault: WaterUnit {
        Locale.current.measurementSystem == .us ? .fluidOunces : .milliliters
    }
}

enum WaterAmount {
    static let millilitersPerFluidOunce = 29.5735

    static func fluidOunces(_ ml: Int) -> Double { Double(ml) / millilitersPerFluidOunce }
    static func milliliters(fluidOunces: Double) -> Int { Int((fluidOunces * millilitersPerFluidOunce).rounded()) }

    /// "250 ml", "1.5 L", "2 L"; "8 fl oz", "68 fl oz".
    static func text(_ ml: Int, unit: WaterUnit) -> String {
        switch unit {
        case .milliliters:
            if ml < 1000 { return String(shared: "\(ml) ml") }
            return String(shared: "\(liters(ml)) L")
        case .fluidOunces:
            return String(shared: "\(Int(fluidOunces(ml).rounded())) fl oz")
        }
    }

    /// Today against the goal in one unit, short enough for a widget: "1.25 of 2 L",
    /// "42 of 68 fl oz".
    static func progress(_ ml: Int, of goal: Int, unit: WaterUnit) -> String {
        switch unit {
        case .milliliters:
            return String(shared: "\(liters(ml)) of \(liters(goal)) L")
        case .fluidOunces:
            return String(shared: "\(Int(fluidOunces(ml).rounded())) of \(Int(fluidOunces(goal).rounded())) fl oz")
        }
    }

    /// "2", "1.5", "1.25": litres without trailing zeros.
    private static func liters(_ ml: Int) -> String {
        let value = Double(ml) / 1000
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2g", value)
    }
}

/// Who the goal is for, as the reference intakes split it. "Rather not say" sits between.
enum WaterSex: String, CaseIterable, Codable, Identifiable {
    case unspecified, female, male

    var id: String { rawValue }
    var label: String {
        switch self {
        case .unspecified: return String(shared: "Rather Not Say")
        case .female: return String(shared: "Female")
        case .male: return String(shared: "Male")
        }
    }

    /// Drinks a day for a reference adult, and that adult's weight.
    var base: (ml: Double, kg: Double) {
        switch self {
        case .female: return (1600, 60)
        case .male: return (2000, 70)
        case .unspecified: return (1800, 65)
        }
    }
}

enum ExerciseIntensity: String, CaseIterable, Codable, Identifiable {
    case moderate, vigorous

    var id: String { rawValue }
    var label: String { self == .moderate ? String(shared: "Moderate") : String(shared: "Vigorous") }
    var detail: String { self == .moderate ? String(shared: "Brisk walking, easy cycling") : String(shared: "Running, sport, hard training") }
    /// Extra drinks for each half hour of exercise.
    var mlPerHalfHour: Double { self == .moderate ? 200 : 400 }
}

/// A personal daily goal for **drinks**, from the evidence in docs/EVIDENCE.md §5:
///
/// - **Base:** EFSA's adequate intakes (2.0 L women, 2.5 L men) include the 20–30% of water
///   that comes from food; as drinks that's 1.6 L and 2.0 L (ESPEN 2022).
/// - **Body weight:** water turnover rises only ~14 ml per kg (Yamada 2022, *Science*), about
///   10 ml/kg of it from drinks, not the 30–35 ml/kg of the old clinical rule, which counts
///   food water too and runs high for heavier people.
/// - **Exercise:** 200 ml (moderate) or 400 ml (vigorous) per half hour of deliberate exercise
///   (ACSM: replace losses; ~1–1.5 ml per kcal).
/// - **Heat:** 500 ml more in hot weather without air conditioning (Yamada's temperature term).
///
/// An estimate for healthy adults, not medical advice.
enum WaterGoal {
    static let perKilogram = 10.0
    static let hotWeatherExtra = 500.0
    /// What the estimate can suggest; a goal typed in by hand may go further.
    static let range = 1200...4000
    /// Kidneys clear about 0.5–0.9 L an hour, so reminders never ask for more than this.
    static let maxPerHour = 500.0
    static let largestGlass = 500

    static func estimate(weightKg: Double, sex: WaterSex = .unspecified, exerciseMinutes: Int = 0,
                         intensity: ExerciseIntensity = .moderate, hot: Bool = false) -> Int {
        let base = sex.base
        var ml = base.ml + perKilogram * (weightKg - base.kg)
        ml += Double(max(exerciseMinutes, 0)) / 30 * intensity.mlPerHalfHour
        if hot { ml += hotWeatherExtra }
        let rounded = Int((ml / 50).rounded()) * 50
        return min(max(rounded, range.lowerBound), range.upperBound)
    }

    /// The shortest gap between reminders for a glass this size: never more than
    /// `maxPerHour` an hour. 30 minutes for a 250 ml glass, an hour for 500 ml.
    static func minimumInterval(glass: Int) -> Int {
        let minutes = Double(max(glass, 1)) / maxPerHour * 60
        return max(Int((minutes / 5).rounded(.up)) * 5, 10)
    }

    /// Minutes between reminders so the goal is drunk, one glass at a time, over `minutes`
    /// of working time; rounded to 5, never closer than `minimumInterval`, at most 3 hours.
    static func reminderInterval(goal: Int, glass: Int, over minutes: Int) -> Int {
        let glasses = max(Int((Double(goal) / Double(max(glass, 1))).rounded(.up)), 1)
        let interval = Double(minutes) / Double(glasses)
        return min(max(Int((interval / 5).rounded()) * 5, minimumInterval(glass: glass)), 180)
    }
}
