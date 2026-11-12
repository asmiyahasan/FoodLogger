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
    static let macrosFromCalories = "macrosFromCalories"
    static let macroPreset = "macroPreset"
    static let customProteinPercent = "customProteinPercent"
    static let customFatPercent = "customFatPercent"
    static let fibreFromCalories = "fibreFromCalories"
    static let userName = "userName"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let waterRemindersOn = "waterRemindersOn"
    static let waterReminderStartHour = "waterReminderStartHour"
    static let waterReminderEndHour = "waterReminderEndHour"
    static let waterReminderIntervalHours = "waterReminderIntervalHours"
    static let pendingLaunchAction = "pendingLaunchAction"
    static let lastBackupDate = "lastBackupDate"
    static let backupIncludesPhotos = "backupIncludesPhotos"
    static let plates = "plates"
    static let lastPlateID = "lastPlateID"

    /// Settings saved in a backup (goals, preferences, name, reminders).
    static let backedUp: [String] = [
        energyUnit, goalEnergyKcal, goalProtein, goalCarbs, goalFat, goalFibre, goalWaterMl,
        quickWater1, quickWater2, keepMealPhotos, macrosFromCalories, macroPreset,
        customProteinPercent, customFatPercent, fibreFromCalories, userName,
        waterRemindersOn, waterReminderStartHour, waterReminderEndHour, waterReminderIntervalHours,
        backupIncludesPhotos, plates,
    ]
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
    static let customProteinPercent = 25.0
    static let customFatPercent = 30.0
    static let reminderStartHour = 9
    static let reminderEndHour = 21
    static let reminderIntervalHours = 2.0
}
