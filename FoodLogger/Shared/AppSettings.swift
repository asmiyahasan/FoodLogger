import Foundation

nonisolated enum EnergyUnit: String, CaseIterable, Identifiable, Sendable {
    case kcal, kJ

    var id: String { rawValue }
    var symbol: String { rawValue }
    var label: String {
        switch self {
        case .kcal: "Calories (kcal)"
        case .kJ: "Kilojoules (kJ)"
        }
    }

    func value(fromKcal kcal: Double) -> Double {
        self == .kcal ? kcal : kcal * Nutrients.kilojoulesPerKilocalorie
    }

    func kcal(from value: Double) -> Double {
        self == .kcal ? value : value / Nutrients.kilojoulesPerKilocalorie
    }

    /// e.g. "1,250 kcal" or "5,230 kJ"
    func format(kcal: Double) -> String {
        "\(value(fromKcal: kcal).formatted(.number.precision(.fractionLength(0)))) \(symbol)"
    }
}

/// Keys for values kept in UserDefaults via @AppStorage.
nonisolated enum SettingsKey {
    static let energyUnit = "energyUnit"
    static let goalEnergyKcal = "goalEnergyKcal"
    static let goalProtein = "goalProtein"
    static let goalCarbs = "goalCarbs"
    static let goalFat = "goalFat"
    static let goalFibre = "goalFibre"
    static let goalWaterMl = "goalWaterMl"
    static let quickWater1 = "quickWater1"
    static let quickWater2 = "quickWater2"
    static let keepMealPhotos = "keepMealPhotos"
}

/// Starting values until the user changes them in Settings.
nonisolated enum GoalDefaults {
    static let energyKcal = 2000.0
    static let protein = 100.0
    static let carbs = 250.0
    static let fat = 70.0
    static let fibre = 30.0
    static let waterMl = 2500.0
    static let quickWater1 = 250.0
    static let quickWater2 = 500.0
}
