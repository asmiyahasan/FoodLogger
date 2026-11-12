import Foundation

/// An item being edited before it is saved to a meal.
struct DraftItem: Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var grams: Double = 100
    var per100g = Nutrients()
    var foodID = ""
    var sourceLabel = "Entered manually"
    var origin: ItemOrigin = .user
    var confidence: Double = 1
    var saveToMyFoods = false

    var nutrients: Nutrients { per100g.scaled(by: grams / 100) }
    var isFromMyFoods: Bool { foodID.hasPrefix("user:") }
}

extension DraftItem {
    init(item: MealItem) {
        self.init(
            name: item.name,
            grams: item.grams,
            per100g: item.nutrientsPer100g,
            foodID: item.foodID,
            sourceLabel: item.sourceLabel,
            origin: item.origin,
            confidence: item.confidence
        )
    }
}
