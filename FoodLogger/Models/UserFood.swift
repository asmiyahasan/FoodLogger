import Foundation
import SwiftData

/// A food the user has saved or corrected, ranked first in future searches.
@Model
final class UserFood {
    var uuid: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var measures: [PortionUnit] = []
    var preferredUnit: String = ""
    /// How your real portions compare with Claude's photo estimates (1.3 = 30% more).
    var portionCorrection: Double = 1
    var correctionSamples: Int = 0
    var aliases: [String] = []
    var nutrientsPer100g: Nutrients = Nutrients()
    var defaultGrams: Double = 100
    var basedOnFoodID: String = ""
    var timesUsed: Int = 0
    var lastUsed: Date = Date.now
    var createdAt: Date = Date.now

    init(name: String, nutrientsPer100g: Nutrients, defaultGrams: Double, basedOnFoodID: String = "") {
        self.name = name
        self.nutrientsPer100g = nutrientsPer100g
        self.defaultGrams = defaultGrams
        self.basedOnFoodID = basedOnFoodID
    }

    var foodID: String { "user:\(uuid.uuidString)" }
}
