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
    /// The dish this ingredient belongs to, if estimated from a recipe.
    var dish = ""
    /// Household measures for this food, and the one chosen ("" = grams).
    var measures: [PortionUnit] = []
    var unitName = ""
    /// Claude's original photo estimate in grams, before any learned adjustment (0 if not estimated).
    var aiGrams: Double = 0

    var nutrients: Nutrients { per100g.scaled(by: grams / 100) }
    var isFromMyFoods: Bool { foodID.hasPrefix("user:") }

    /// This food's measures plus tbsp/tsp.
    var availableMeasures: [PortionUnit] {
        measures + PortionUnit.spoons.filter { spoon in !measures.contains { $0.name == spoon.name } }
    }

    var selectedUnit: PortionUnit? {
        unitName.isEmpty ? nil : availableMeasures.first { $0.name == unitName }
    }

    /// "1½ cups (240 g)" or "240 g"
    var amountText: String {
        guard let unit = selectedUnit, unit.grams > 0 else { return gramsText(grams) }
        return "\(unit.label(quantity: grams / unit.grams)) (\(gramsText(grams.rounded())))"
    }
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
            confidence: item.confidence,
            dish: item.dish,
            measures: item.measures,
            unitName: item.unitName
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
        dish = parsed.dish
        aiGrams = parsed.grams
        measures = parsed.measures
        if let serving = parsed.food?.servingGrams, serving > 0, !measures.contains(where: { $0.name == "serving" }) {
            measures.append(PortionUnit(name: "serving", grams: serving))
        }
        if let savedMeasures = parsed.food?.measures {
            for unit in savedMeasures where !measures.contains(where: { $0.name == unit.name }) {
                measures.append(unit)
            }
        }
        let preferred = parsed.displayUnit.isEmpty ? (parsed.food?.preferredUnit ?? "") : parsed.displayUnit
        unitName = availableMeasures.contains { $0.name == preferred } ? preferred : ""
    }
}
