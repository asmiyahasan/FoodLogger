import Foundation

/// Open Food Facts: branded and packaged products. Free, no key.
/// Limits: about 100 product lookups and 10 searches per minute.
nonisolated struct OpenFoodFactsClient: Sendable {
    private static let fields = "code,product_name,brands,quantity,serving_quantity,nutriments"
    private static let userAgent = "FoodLogger/1.0 (personal iOS app)"

    /// Searches products sold in Australia.
    func search(_ query: String) async throws -> [FoodCandidate] {
        var components = URLComponents(string: "https://au.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "15"),
            URLQueryItem(name: "fields", value: Self.fields),
        ]
        let response: OFFSearchResponse = try await get(components.url!)
        return (response.products ?? []).compactMap(\.candidate)
    }

    /// Looks up one product by its barcode.
    func product(barcode: String) async throws -> FoodCandidate? {
        let digits = barcode.filter(\.isNumber)
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=\(Self.fields)")
        else { return nil }
        let response: OFFProductResponse = try await get(url)
        return response.product?.candidate
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 429 { throw FoodSearchError.rateLimited }
        guard (200..<300).contains(status) else { throw FoodSearchError.badResponse(status) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

nonisolated struct OFFSearchResponse: Decodable, Sendable {
    var products: [OFFProduct]?
}

nonisolated struct OFFProductResponse: Decodable, Sendable {
    var product: OFFProduct?
}

nonisolated struct OFFProduct: Decodable, Sendable {
    var code: String?
    var productName: String?
    var brands: String?
    var quantity: String?
    var servingQuantity: FlexibleDouble?
    var nutriments: [String: FlexibleDouble]?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case servingQuantity = "serving_quantity"
        case nutriments
    }

    var candidate: FoodCandidate? {
        guard let code,
              let name = productName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let nutriments
        else { return nil }

        func value(_ key: String) -> Double? { nutriments[key]?.value }

        // energy_100g and energy-kj_100g are kilojoules.
        let kilojoules = value("energy-kj_100g") ?? value("energy_100g")
        guard let kcal = value("energy-kcal_100g") ?? kilojoules.map({ $0 / Nutrients.kilojoulesPerKilocalorie }) else {
            return nil // No energy value: not usable.
        }

        let per100g = Nutrients(
            energyKcal: kcal,
            protein: value("proteins_100g") ?? 0,
            fat: value("fat_100g") ?? 0,
            saturatedFat: value("saturated-fat_100g") ?? 0,
            carbs: value("carbohydrates_100g") ?? 0,
            sugars: value("sugars_100g") ?? 0,
            fibre: value("fiber_100g") ?? 0,
            sodiumMg: (value("sodium_100g") ?? 0) * 1000 // sodium is given in grams
        )

        let brand = brands?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let detailParts = [brand, quantity].compactMap { $0 }.filter { !$0.isEmpty }

        return FoodCandidate(
            id: "off:\(code)",
            name: name,
            detail: detailParts.isEmpty ? "Label values" : detailParts.joined(separator: " · "),
            source: .openFoodFacts,
            per100g: per100g,
            servingGrams: servingQuantity?.value,
            brand: brand
        )
    }
}
