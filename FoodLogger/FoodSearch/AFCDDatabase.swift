import Foundation

/// One food from the bundled Australian Food Composition Database (FSANZ, Release 3).
/// `n` = per 100 g: [kcal, protein g, fat g, saturated fat g, carbs g, sugars g, fibre g, sodium mg]
nonisolated struct AFCDFood: Decodable, Sendable {
    let id: String
    let name: String
    let n: [Double]

    var nutrients: Nutrients {
        func at(_ index: Int) -> Double { index < n.count ? n[index] : 0 }
        return Nutrients(
            energyKcal: at(0), protein: at(1), fat: at(2), saturatedFat: at(3),
            carbs: at(4), sugars: at(5), fibre: at(6), sodiumMg: at(7)
        )
    }
}

/// Searches the bundled AFCD file (afcd.json). Works offline, no limits.
actor AFCDDatabase {
    static let shared = AFCDDatabase()

    private var foods: [AFCDFood]?

    var isAvailable: Bool {
        Bundle.main.url(forResource: "afcd", withExtension: "json") != nil
    }

    func search(_ query: String, limit: Int = 12) -> [FoodCandidate] {
        let terms = SearchRanking.terms(for: query)
        guard !terms.isEmpty else { return [] }

        return loadIfNeeded()
            .compactMap { food -> (score: Int, food: AFCDFood)? in
                guard let score = SearchRanking.score(name: food.name, terms: terms) else { return nil }
                return (score, food)
            }
            .sorted { $0.score < $1.score }
            .prefix(limit)
            .map { match in
                FoodCandidate(
                    id: "afcd:\(match.food.id)",
                    name: match.food.name,
                    detail: "Australian lab values",
                    source: .afcd,
                    per100g: match.food.nutrients,
                    servingGrams: nil
                )
            }
    }

    private func loadIfNeeded() -> [AFCDFood] {
        if let foods { return foods }
        guard let url = Bundle.main.url(forResource: "afcd", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([AFCDFood].self, from: data)
        else {
            foods = []
            return []
        }
        foods = decoded
        return decoded
    }
}
