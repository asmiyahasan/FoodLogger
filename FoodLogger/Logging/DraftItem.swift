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
    /// Remember this food (on by default) so it's suggested next time.
    var saveToMyFoods = true
    /// A question or caveat from the AI, e.g. "Fried in oil?"
    var note = ""
    /// The database entry's own name, e.g. "Egg, chicken, whole, fried".
    var matchedName = ""
    var brand = ""

    var nutrients: Nutrients { per100g.scaled(by: grams / 100) }
    var isFromMyFoods: Bool { foodID.hasPrefix("user:") }
    /// Shown with a Check tag on the review screen.
    var needsCheck: Bool { confidence < 0.6 || (foodID.isEmpty && origin != .user) }
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

extension DraftItem {
    init(parsed: ParsedMealItem) {
        if let food = parsed.food {
            self.init(
                name: parsed.name,
                grams: parsed.grams,
                per100g: food.per100g,
                foodID: food.id,
                sourceLabel: food.source.shortLabel,
                origin: parsed.origin,
                confidence: parsed.confidence
            )
            matchedName = food.name
            brand = food.brand ?? ""
        } else {
            self.init(
                name: parsed.name,
                grams: parsed.grams,
                per100g: Nutrients(),
                foodID: "",
                sourceLabel: "No database match",
                origin: parsed.origin,
                confidence: 0
            )
        }
        note = parsed.food == nil ? "No match found. Tap to search." : parsed.note
    }
}
