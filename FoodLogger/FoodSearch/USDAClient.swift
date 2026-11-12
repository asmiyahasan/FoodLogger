import Foundation

/// USDA FoodData Central: generic foods with lab values. Free key, 1,000 requests/hour.
nonisolated struct USDAClient: Sendable {
    let apiKey: String

    func search(_ query: String) async throws -> [FoodCandidate] {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: "Foundation,SR Legacy"),
            URLQueryItem(name: "pageSize", value: "10"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: break
        case 401, 403: throw FoodSearchError.invalidKey
        case 429: throw FoodSearchError.rateLimited
        default: throw FoodSearchError.badResponse(status)
        }
        let decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return (decoded.foods ?? []).compactMap(\.candidate)
    }
}

nonisolated struct USDASearchResponse: Decodable, Sendable {
    var foods: [USDAFood]?
}

nonisolated struct USDAFood: Decodable, Sendable {
    var fdcId: Int
    var description: String
    var dataType: String?
    var foodNutrients: [USDANutrient]?

    var candidate: FoodCandidate? {
        let nutrients = foodNutrients ?? []
        func value(_ ids: Int...) -> Double? {
            for id in ids {
                if let match = nutrients.first(where: { $0.nutrientId == id })?.value { return match }
            }
            return nil
        }

        // 1008 = Energy (kcal); 2047/2048 = Atwater energy (kcal); 1062 = Energy (kJ).
        guard let kcal = value(1008, 2048, 2047) ?? value(1062).map({ $0 / Nutrients.kilojoulesPerKilocalorie }) else {
            return nil
        }

        let per100g = Nutrients(
            energyKcal: kcal,
            protein: value(1003) ?? 0,
            fat: value(1004) ?? 0,
            saturatedFat: value(1258) ?? 0,
            carbs: value(1005) ?? 0,
            sugars: value(2000, 1063) ?? 0,
            fibre: value(1079) ?? 0,
            sodiumMg: value(1093) ?? 0
        )

        return FoodCandidate(
            id: "usda:\(fdcId)",
            name: description.prefix(1).uppercased() + description.dropFirst().lowercased(),
            detail: dataType == "Foundation" ? "Lab values" : "Generic",
            source: .usda,
            per100g: per100g,
            servingGrams: nil
        )
    }
}

nonisolated struct USDANutrient: Decodable, Sendable {
    var nutrientId: Int?
    var value: Double?
}
