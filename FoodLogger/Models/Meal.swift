import Foundation
import SwiftData

// iCloud-ready rules (so sync is a switch later, not a migration):
// every property has a default or is optional, relationships are optional,
// no unique constraints, photos stored outside the database.

@Model
final class Meal {
    var timestamp: Date = Date.now
    var mealTypeRaw: String = MealType.snack.rawValue
    var statusRaw: String = MealStatus.logged.rawValue
    var transcript: String = ""
    @Attribute(.externalStorage) var photo: Data?
    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal)
    var items: [MealItem]? = []

    init(timestamp: Date = .now, mealType: MealType? = nil, status: MealStatus = .logged) {
        self.timestamp = timestamp
        self.mealTypeRaw = (mealType ?? MealType.inferred(from: timestamp)).rawValue
        self.statusRaw = status.rawValue
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var status: MealStatus {
        get { MealStatus(rawValue: statusRaw) ?? .logged }
        set { statusRaw = newValue.rawValue }
    }

    var sortedItems: [MealItem] {
        (items ?? []).sorted { $0.position < $1.position }
    }

    var totals: Nutrients {
        (items ?? []).reduce(Nutrients.zero) { $0 + $1.nutrients }
    }

    /// A short name for lists, built from the item names.
    var title: String {
        let names = sortedItems.map(\.name).filter { !$0.isEmpty }
        switch names.count {
        case 0: return mealType.label
        case 1, 2: return names.joined(separator: " and ")
        default: return "\(names[0]), \(names[1]) + \(names.count - 2) more"
        }
    }
}

@Model
final class MealItem {
    var name: String = ""
    var grams: Double = 0
    /// Source-prefixed ID: "afcd:…", "off:…", "usda:…", "user:…" or empty for manual entries.
    var foodID: String = ""
    var sourceLabel: String = ""
    var originRaw: String = ItemOrigin.user.rawValue
    var confidence: Double = 1
    var position: Int = 0
    /// Copied when logged, so history never changes if a database updates.
    var nutrientsPer100g: Nutrients = Nutrients()
    var meal: Meal?

    init(
        name: String,
        grams: Double,
        nutrientsPer100g: Nutrients,
        foodID: String = "",
        sourceLabel: String = "Entered manually",
        origin: ItemOrigin = .user,
        confidence: Double = 1,
        position: Int = 0
    ) {
        self.name = name
        self.grams = grams
        self.nutrientsPer100g = nutrientsPer100g
        self.foodID = foodID
        self.sourceLabel = sourceLabel
        self.originRaw = origin.rawValue
        self.confidence = confidence
        self.position = position
    }

    var origin: ItemOrigin {
        get { ItemOrigin(rawValue: originRaw) ?? .user }
        set { originRaw = newValue.rawValue }
    }

    /// Nutrients for this item's amount. The app does this maths, never the AI.
    var nutrients: Nutrients {
        nutrientsPer100g.scaled(by: grams / 100)
    }
}
