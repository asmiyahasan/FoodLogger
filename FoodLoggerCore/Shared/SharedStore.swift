import Foundation
import SwiftData

/// The App Group that the app and the widget both read from.
nonisolated enum AppGroup {
    static let identifier = "group.com.asmiyahasan.FoodLogger"

    /// Settings both sides can read. The app copies its settings in here (see SettingsMirror);
    /// the widget only reads them.
    static let settings: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard

    /// Folder shared by the app and the widget.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// True when this code is running inside the widget extension rather than the app.
    static var isExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }
}

/// The one database, shared by the app, the widget, notification buttons and Siri.
enum SharedStore {
    static let container: ModelContainer = {
        let schema = Schema([Meal.self, MealItem.self, UserFood.self, WaterEntry.self])
        do {
            guard let storeURL = groupStoreURL else {
                // App Group unavailable (shouldn't happen): fall back to the app's own store.
                return try ModelContainer(for: schema)
            }
            if !AppGroup.isExtension {
                StoreMigration.moveOldStoreIfNeeded(to: storeURL)
            }
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
        } catch {
            fatalError("Couldn't open the FoodLogger database: \(error)")
        }
    }()

    static var groupStoreURL: URL? {
        guard let base = AppGroup.containerURL else { return nil }
        let folder = base.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "FoodLogger.store")
    }
}

/// One-time move of the database from the app's private folder into the App Group,
/// so the widget can see it. The old files are renamed (not deleted) as a safety copy.
nonisolated enum StoreMigration {
    private static let doneKey = "storeMovedToAppGroup"

    static func moveOldStoreIfNeeded(to newURL: URL) {
        let defaults = AppGroup.settings
        guard !defaults.bool(forKey: doneKey) else { return }

        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldURL = appSupport.appending(path: "default.store")

        if fm.fileExists(atPath: oldURL.path) {
            let suffixes = ["", "-shm", "-wal"]
            // Anything already at the new location (e.g. an empty store the widget made) is replaced.
            for suffix in suffixes {
                let target = URL(fileURLWithPath: newURL.path + suffix)
                if fm.fileExists(atPath: target.path) { try? fm.removeItem(at: target) }
            }
            for suffix in suffixes {
                let source = URL(fileURLWithPath: oldURL.path + suffix)
                guard fm.fileExists(atPath: source.path) else { continue }
                do {
                    try fm.copyItem(at: source, to: URL(fileURLWithPath: newURL.path + suffix))
                } catch {
                    print("Store migration failed: \(error)")
                    return   // try again next launch; the old store is untouched
                }
            }
            // Keep the old files as a backup under a new name.
            for suffix in suffixes {
                let source = URL(fileURLWithPath: oldURL.path + suffix)
                guard fm.fileExists(atPath: source.path) else { continue }
                try? fm.moveItem(at: source, to: URL(fileURLWithPath: oldURL.path + ".premigration" + suffix))
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}

/// Today's totals and goals, read outside the main UI (Siri, notifications, the widget).
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

    static func waterToday(context: ModelContext) -> Double {
        let (start, end) = todayRange()
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { entry in entry.timestamp >= start && entry.timestamp < end }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.millilitres }
    }

    private static var defaults: UserDefaults { AppGroup.settings }

    static var energyUnit: EnergyUnit {
        EnergyUnit(rawValue: defaults.string(forKey: SettingsKey.energyUnit) ?? "") ?? .kcal
    }

    static var energyGoalKcal: Double {
        defaults.object(forKey: SettingsKey.goalEnergyKcal) as? Double ?? GoalDefaults.energyKcal
    }

    static var waterGoalMl: Double {
        defaults.object(forKey: SettingsKey.goalWaterMl) as? Double ?? GoalDefaults.waterMl
    }

    static var macroGoals: MacroGoals {
        let defaults = self.defaults
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
