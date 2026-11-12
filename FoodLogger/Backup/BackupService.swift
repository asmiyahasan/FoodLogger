import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File format

nonisolated struct BackupFile: Codable, Sendable {
    var app = "FoodLogger"
    var version = 1
    var exportedAt: Date
    var settings: [String: SettingValue]
    var meals: [MealRecord]
    var water: [WaterRecord]
    var savedFoods: [SavedFoodRecord]
}

nonisolated enum SettingValue: Codable, Sendable {
    case bool(Bool), int(Int), double(Double), string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    var object: Any {
        switch self {
        case .bool(let value): value
        case .int(let value): value
        case .double(let value): value
        case .string(let value): value
        }
    }
}

nonisolated struct MealRecord: Codable, Sendable {
    var timestamp: Date
    var mealType: String
    var status: String
    var transcript: String
    var photo: Data?
    var items: [ItemRecord]
}

nonisolated struct ItemRecord: Codable, Sendable {
    var name: String
    var grams: Double
    var foodID: String
    var sourceLabel: String
    var origin: String
    var confidence: Double
    var position: Int
    var nutrientsPer100g: Nutrients
    var dish: String?
    var unitName: String?
    var measures: [PortionUnit]?
}

nonisolated struct WaterRecord: Codable, Sendable {
    var timestamp: Date
    var millilitres: Double
}

nonisolated struct SavedFoodRecord: Codable, Sendable {
    var uuid: UUID
    var name: String
    var brand: String?
    var measures: [PortionUnit]?
    var preferredUnit: String?
    var portionCorrection: Double?
    var correctionSamples: Int?
    var aliases: [String]
    var nutrientsPer100g: Nutrients
    var defaultGrams: Double
    var basedOnFoodID: String
    var timesUsed: Int
    var lastUsed: Date
    var createdAt: Date
}

/// Wraps backup bytes for the system "Save to Files" sheet.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

nonisolated enum BackupError: LocalizedError {
    case notABackup
    var errorDescription: String? { "That file isn't a FoodLogger backup." }
}

// MARK: - Backup and restore

enum BackupService {
    static var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: SettingsKey.lastBackupDate) as? Date
    }

    /// No backup yet, or the last one is over a week old.
    static var backupIsDue: Bool {
        guard let lastBackupDate else { return true }
        return Date.now.timeIntervalSince(lastBackupDate) > 7 * 86_400
    }

    static func markBackedUp() {
        UserDefaults.standard.set(Date.now, forKey: SettingsKey.lastBackupDate)
    }

    static func makeBackup(context: ModelContext, includePhotos: Bool) throws -> Data {
        let meals = try context.fetch(FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.timestamp)]))
        let water = try context.fetch(FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.timestamp)]))
        let foods = try context.fetch(FetchDescriptor<UserFood>())

        let file = BackupFile(
            exportedAt: .now,
            settings: currentSettings(),
            meals: meals.map { meal in
                MealRecord(
                    timestamp: meal.timestamp,
                    mealType: meal.mealTypeRaw,
                    status: meal.statusRaw,
                    transcript: meal.transcript,
                    photo: includePhotos ? meal.photo : nil,
                    items: meal.sortedItems.map { item in
                        ItemRecord(
                            name: item.name, grams: item.grams, foodID: item.foodID,
                            sourceLabel: item.sourceLabel, origin: item.originRaw,
                            confidence: item.confidence, position: item.position,
                            nutrientsPer100g: item.nutrientsPer100g, dish: item.dish,
                            unitName: item.unitName, measures: item.measures
                        )
                    }
                )
            },
            water: water.map { WaterRecord(timestamp: $0.timestamp, millilitres: $0.millilitres) },
            savedFoods: foods.map { food in
                SavedFoodRecord(
                    uuid: food.uuid, name: food.name, brand: food.brand,
                    measures: food.measures, preferredUnit: food.preferredUnit,
                    portionCorrection: food.portionCorrection, correctionSamples: food.correctionSamples,
                    aliases: food.aliases,
                    nutrientsPer100g: food.nutrientsPer100g, defaultGrams: food.defaultGrams,
                    basedOnFoodID: food.basedOnFoodID, timesUsed: food.timesUsed,
                    lastUsed: food.lastUsed, createdAt: food.createdAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    static func read(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(BackupFile.self, from: data), file.app == "FoodLogger" else {
            throw BackupError.notABackup
        }
        return file
    }

    /// Replaces everything in the app with the backup's contents.
    static func restore(_ file: BackupFile, context: ModelContext) throws {
        for meal in try context.fetch(FetchDescriptor<Meal>()) { context.delete(meal) }
        for entry in try context.fetch(FetchDescriptor<WaterEntry>()) { context.delete(entry) }
        for food in try context.fetch(FetchDescriptor<UserFood>()) { context.delete(food) }
        try context.save()

        for record in file.meals {
            let meal = Meal(timestamp: record.timestamp, mealType: MealType(rawValue: record.mealType))
            meal.statusRaw = record.status
            meal.transcript = record.transcript
            meal.photo = record.photo
            context.insert(meal)
            for itemRecord in record.items {
                let item = MealItem(
                    name: itemRecord.name,
                    grams: itemRecord.grams,
                    nutrientsPer100g: itemRecord.nutrientsPer100g,
                    foodID: itemRecord.foodID,
                    sourceLabel: itemRecord.sourceLabel,
                    origin: ItemOrigin(rawValue: itemRecord.origin) ?? .user,
                    confidence: itemRecord.confidence,
                    position: itemRecord.position,
                    dish: itemRecord.dish ?? "",
                    unitName: itemRecord.unitName ?? "",
                    measures: itemRecord.measures ?? []
                )
                context.insert(item)
                item.meal = meal
            }
        }
        for record in file.water {
            context.insert(WaterEntry(millilitres: record.millilitres, timestamp: record.timestamp))
        }
        for record in file.savedFoods {
            let food = UserFood(
                name: record.name,
                nutrientsPer100g: record.nutrientsPer100g,
                defaultGrams: record.defaultGrams,
                basedOnFoodID: record.basedOnFoodID
            )
            food.uuid = record.uuid
            food.brand = record.brand ?? ""
            food.measures = record.measures ?? []
            food.preferredUnit = record.preferredUnit ?? ""
            food.portionCorrection = record.portionCorrection ?? 1
            food.correctionSamples = record.correctionSamples ?? 0
            food.aliases = record.aliases
            food.timesUsed = record.timesUsed
            food.lastUsed = record.lastUsed
            food.createdAt = record.createdAt
            context.insert(food)
        }
        try context.save()

        let defaults = UserDefaults.standard
        for (key, value) in file.settings where SettingsKey.backedUp.contains(key) {
            defaults.set(value.object, forKey: key)
        }
    }

    private static func currentSettings() -> [String: SettingValue] {
        var result: [String: SettingValue] = [:]
        let defaults = UserDefaults.standard
        for key in SettingsKey.backedUp {
            guard let object = defaults.object(forKey: key) else { continue }
            if let number = object as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    result[key] = .bool(number.boolValue)
                } else if CFNumberIsFloatType(number) {
                    result[key] = .double(number.doubleValue)
                } else {
                    result[key] = .int(number.intValue)
                }
            } else if let text = object as? String {
                result[key] = .string(text)
            }
        }
        return result
    }
}
