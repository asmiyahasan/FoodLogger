import Foundation

/// Finds a product by barcode: your saved foods first (instant, offline), then Open Food Facts.
nonisolated enum BarcodeLookup {
    static func foodID(for barcode: String) -> String {
        "off:\(barcode.filter(\.isNumber))"
    }

    /// `savedFoods` pairs each saved food's source ID with its candidate.
    static func find(_ barcode: String, savedFoods: [(basedOn: String, food: FoodCandidate)]) async throws -> FoodCandidate? {
        let id = foodID(for: barcode)
        if let saved = savedFoods.first(where: { $0.basedOn == id }) {
            return saved.food
        }
        return try await OpenFoodFactsClient().product(barcode: barcode)
    }
}
