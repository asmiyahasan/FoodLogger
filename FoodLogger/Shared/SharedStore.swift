import Foundation
import SwiftData

/// The one database, shared by the app, notification buttons and Siri.
enum SharedStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Meal.self, MealItem.self, UserFood.self, WaterEntry.self)
        } catch {
            fatalError("Couldn't open the FoodLogger database: \(error)")
        }
    }()
}

/// Today's totals and goals, read outside the UI (Siri, notifications).
enum DailySnapshot {
    static func todayRange() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    static func eatenToday(context: ModelContext) -> Nutrients {
        let (start, end) = todayRange()
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in meal.timestamp >= start && meal.timestamp < end }
        )
        let meals = (try? context.fetch(descriptor)) ?? []
        return meals
            .filter { $0.status == .logged }
            .reduce(Nutrients.zero) { $0 + $1.totals }
    }

    static var energyUnit: EnergyUnit {
        EnergyUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.energyUnit) ?? "") ?? .kcal
    }

    static var energyGoalKcal: Double {
        UserDefaults.standard.object(forKey: SettingsKey.goalEnergyKcal) as? Double ?? GoalDefaults.energyKcal
    }

    static var waterGoalMl: Double {
        UserDefaults.standard.object(forKey: SettingsKey.goalWaterMl) as? Double ?? GoalDefaults.waterMl
    }

    static var macroGoals: MacroGoals {
        let defaults = UserDefaults.standard
        return MacroGoals.effective(
            fromCalories: defaults.object(forKey: SettingsKey.macrosFromCalories) as? Bool ?? true,
            energyKcal: energyGoalKcal,
            preset: MacroPreset(rawValue: defaults.string(forKey: SettingsKey.macroPreset) ?? "") ?? .balanced,
            customProteinPercent: defaults.object(forKey: SettingsKey.customProteinPercent) as? Double ?? GoalDefaults.customProteinPercent,
            customFatPercent: defaults.object(forKey: SettingsKey.customFatPercent) as? Double ?? GoalDefaults.customFatPercent,
            manual: MacroGoals(
                protein: defaults.object(forKey: SettingsKey.goalProtein) as? Double ?? GoalDefaults.protein,
                carbs: defaults.object(forKey: SettingsKey.goalCarbs) as? Double ?? GoalDefaults.carbs,
                fat: defaults.object(forKey: SettingsKey.goalFat) as? Double ?? GoalDefaults.fat
            )
        )
    }
}
