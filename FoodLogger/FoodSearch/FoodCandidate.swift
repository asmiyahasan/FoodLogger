import Foundation

nonisolated enum FoodSource: String, Codable, CaseIterable, Sendable {
    case mine, afcd, openFoodFacts, usda

    /// Section titles in search results.
    var title: String {
        switch self {
        case .mine: "My foods"
        case .afcd: "Australian Food Composition Database"
        case .openFoodFacts: "Open Food Facts"
        case .usda: "USDA FoodData Central"
        }
    }

    /// Short label shown on meal items.
    var shortLabel: String {
        switch self {
        case .mine: "My foods"
        case .afcd: "AFCD"
        case .openFoodFacts: "Open Food Facts"
        case .usda: "USDA"
        }
    }
}

/// One search result. Every number in it comes from a database, never from AI.
nonisolated struct FoodCandidate: Identifiable, Hashable, Sendable {
    /// Source-prefixed ID, e.g. "afcd:F002345", "off:9300633…", "usda:171287", "user:…".
    var id: String
    var name: String
    var detail: String
    var source: FoodSource
    var per100g: Nutrients
    /// A typical serving in grams, when the source gives one.
    var servingGrams: Double?
}

nonisolated enum FoodSearchError: LocalizedError, Sendable {
    case badResponse(Int)
    case invalidKey
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): "The service didn't respond properly (code \(code)). Try again shortly."
        case .invalidKey: "Your API key was rejected. Check it in Settings."
        case .rateLimited: "Too many searches in a short time. Wait a minute and try again."
        }
    }
}

/// Decodes a number whether the JSON has it as a number or a string; never fails.
nonisolated struct FlexibleDouble: Decodable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
        } else if let text = try? container.decode(String.self) {
            value = Double(text.replacingOccurrences(of: ",", with: "."))
        } else {
            value = nil
        }
    }
}
