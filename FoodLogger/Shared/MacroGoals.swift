import Foundation

/// How the calorie goal is split between protein, carbs and fat.
nonisolated enum MacroPreset: String, CaseIterable, Identifiable, Sendable {
    case balanced, higherProtein, lowerCarb, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: "Balanced"
        case .higherProtein: "Higher protein"
        case .lowerCarb: "Lower carb"
        case .custom: "Custom"
        }
    }

    /// Protein % and fat %; carbs get the rest. Nil for custom.
    var split: (protein: Double, fat: Double)? {
        switch self {
        case .balanced: (20, 30)        // carbs 50
        case .higherProtein: (30, 30)   // carbs 40
        case .lowerCarb: (30, 40)       // carbs 30
        case .custom: nil
        }
    }
}

/// Daily protein, carbs and fat goals in grams.
nonisolated struct MacroGoals: Sendable {
    var protein: Double
    var carbs: Double
    var fat: Double

    static let kcalPerGramProtein = 4.0
    static let kcalPerGramCarbs = 4.0
    static let kcalPerGramFat = 9.0

    /// Grams from a calorie goal and a percentage split (carbs = 100 − protein − fat).
    static func from(energyKcal: Double, proteinPercent: Double, fatPercent: Double) -> MacroGoals {
        let carbsPercent = max(100 - proteinPercent - fatPercent, 0)
        return MacroGoals(
            protein: energyKcal * proteinPercent / 100 / kcalPerGramProtein,
            carbs: energyKcal * carbsPercent / 100 / kcalPerGramCarbs,
            fat: energyKcal * fatPercent / 100 / kcalPerGramFat
        )
    }

    /// The goals actually in use, from the saved settings.
    static func effective(
        fromCalories: Bool,
        energyKcal: Double,
        preset: MacroPreset,
        customProteinPercent: Double,
        customFatPercent: Double,
        manual: MacroGoals
    ) -> MacroGoals {
        guard fromCalories else { return manual }
        let split = preset.split ?? (protein: customProteinPercent, fat: customFatPercent)
        return from(energyKcal: energyKcal, proteinPercent: split.protein, fatPercent: split.fat)
    }
}
