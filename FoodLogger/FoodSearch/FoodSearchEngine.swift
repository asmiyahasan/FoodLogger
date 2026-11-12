import Foundation

/// The food lookup the AI uses. It searches your foods and the Australian database first,
/// and only goes online (Open Food Facts, USDA) when those don't have enough matches,
/// which keeps analysis fast and within rate limits.
nonisolated struct FoodSearchEngine: Sendable {
    let userFoods: [FoodCandidate]
    let usdaKey: String?

    func search(_ query: String) async -> [FoodCandidate] {
        var results = Array(SearchRanking.rank(userFoods, for: query).prefix(3))
        results += await AFCDDatabase.shared.search(query, limit: 5)

        let wantsBrand = query.split(separator: " ").count >= 3 || results.count < 2
        if wantsBrand, let branded = try? await OpenFoodFactsClient().search(query) {
            results += SearchRanking.rank(branded, for: query).prefix(4)
        }
        if results.count < 2, let usdaKey, let generic = try? await USDAClient(apiKey: usdaKey).search(query) {
            results += SearchRanking.rank(generic, for: query).prefix(3)
        }
        if results.isEmpty {
            results = await closestMatches(for: query)
        }
        return results
    }

    /// When nothing matches every word ("flaked almonds"), search each word on its own
    /// ("almond") so the closest real foods are still offered.
    private func closestMatches(for query: String) async -> [FoodCandidate] {
        let words = SearchRanking.terms(for: query)
        guard words.count > 1 else { return [] }
        var results: [FoodCandidate] = []
        for word in words.sorted(by: { $0.count > $1.count }) where word.count > 2 {
            results += SearchRanking.rank(userFoods, for: word).prefix(2)
            results += await AFCDDatabase.shared.search(word, limit: 3)
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
    }
}

extension UserFood {
    var candidate: FoodCandidate {
        FoodCandidate(
            id: foodID,
            name: name,
            detail: "Usually \(gramsText(defaultGrams))",
            source: .mine,
            per100g: nutrientsPer100g,
            servingGrams: defaultGrams
        )
    }
}
