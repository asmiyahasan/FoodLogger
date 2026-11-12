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
    /// The product's brand, for branded foods.
    var brand: String? = nil
    /// Household measures for this food (from your saved foods).
    var measures: [PortionUnit] = []
    /// The measure you usually use for it, e.g. "cup".
    var preferredUnit: String = ""
}

/// A household measure and its weight, e.g. 1 cup of cooked rice ≈ 160 g.
nonisolated struct PortionUnit: Codable, Hashable, Sendable, Identifiable {
    var name: String
    var grams: Double

    var id: String { name }

    /// Available for every food.
    static let spoons = [PortionUnit(name: "tbsp", grams: 15), PortionUnit(name: "tsp", grams: 5)]

    /// Whole items move in halves; everything else in quarters.
    var step: Double {
        ["piece", "slice", "serving", "egg", "roti", "paratha", "naan"].contains(name) ? 0.5 : 0.25
    }

    /// "1½ cups", "2 pieces", "¾ ladle"
    func label(quantity: Double) -> String {
        "\(Self.fraction(quantity)) \(quantity > 1 ? Self.plural(name) : name)"
    }

    static func fraction(_ quantity: Double) -> String {
        let rounded = (quantity * 4).rounded() / 4
        guard rounded > 0 else { return quantity.formatted(.number.precision(.fractionLength(0...2))) }
        let whole = Int(rounded)
        let symbol: String
        switch rounded - Double(whole) {
        case 0.25: symbol = "¼"
        case 0.5: symbol = "½"
        case 0.75: symbol = "¾"
        default: symbol = ""
        }
        return whole == 0 ? symbol : "\(whole)\(symbol)"
    }

    static func plural(_ name: String) -> String {
        if ["tbsp", "tsp", "g", "ml"].contains(name) { return name }
        if name.hasSuffix("s") || name.hasSuffix("x") || name.hasSuffix("ch") || name.hasSuffix("sh") {
            return name + "es"
        }
        return name + "s"
    }
}

/// A food you've logged before, as used for search and by Claude.
nonisolated struct SavedFood: Sendable {
    var candidate: FoodCandidate
    var aliases: [String]
    var timesUsed: Int
    var basedOn: String
}

/// Ranks your saved foods: matching any of their names, with frequent ones first.
nonisolated enum SavedFoodRanking {
    static func rank(_ foods: [SavedFood], for query: String) -> [FoodCandidate] {
        let terms = SearchRanking.terms(for: query)
        guard !terms.isEmpty else {
            return foods.sorted { $0.timesUsed > $1.timesUsed }.map(\.candidate)
        }
        return foods
            .compactMap { food -> (score: Int, food: FoodCandidate)? in
                var names = [food.candidate.name] + food.aliases
                if let brand = food.candidate.brand, !brand.isEmpty {
                    names.append("\(brand) \(food.candidate.name)")
                }
                guard let best = names.compactMap({ SearchRanking.score(name: $0, terms: terms) }).min() else {
                    return nil
                }
                return (best - min(food.timesUsed * 5, 60), food.candidate)
            }
            .sorted { $0.score < $1.score }
            .map(\.food)
    }
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
