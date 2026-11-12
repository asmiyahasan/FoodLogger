import Foundation

/// Finds household measures (cup, slice, piece…) and the right spoon weights for a food picked
/// from search. The databases only give values per 100 g, so without this you'd only get grams
/// and a generic tbsp/tsp.
///
/// Order: USDA's own measured portions (real data) when the food is from USDA, then Claude's
/// typical weights to fill the gaps. Results are saved, so each food is only looked up once.
/// Only weights come from here; nutrition values always come from the database.
enum MeasureLookup {
    static func measures(for food: FoodCandidate) async -> [PortionUnit] {
        if let saved = MeasureCache.measures(for: food.id) { return saved }

        var result: [PortionUnit] = []
        if food.id.hasPrefix("usda:"), let key = APIKeys.value(for: .usdaAPIKey) {
            let fdcID = String(food.id.dropFirst("usda:".count))
            result = (try? await usdaPortions(fdcID: fdcID, apiKey: key)) ?? []
        }
        if let key = APIKeys.value(for: .claudeAPIKey),
           let suggested = try? await claudeMeasures(for: food, apiKey: key) {
            for unit in suggested where !result.contains(where: { $0.name == unit.name }) {
                result.append(unit)
            }
        }
        result = Array(result.prefix(6))
        if !result.isEmpty { MeasureCache.save(result, for: food.id) }
        return result
    }

    // MARK: - USDA portions

    private static func usdaPortions(fdcID: String, apiKey: String) async throws -> [PortionUnit] {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/food/\(fdcID)")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let portions = json["foodPortions"] as? [[String: Any]]
        else { return [] }

        var units: [PortionUnit] = []
        for portion in portions {
            guard let gramWeight = portion["gramWeight"] as? Double, gramWeight > 0 else { continue }
            let amount = (portion["amount"] as? Double).flatMap { $0 > 0 ? $0 : nil } ?? 1
            let unitName = (portion["measureUnit"] as? [String: Any])?["name"] as? String
            let candidates = [unitName, portion["modifier"] as? String, portion["portionDescription"] as? String]
            guard let name = candidates.compactMap({ $0 }).lazy.compactMap(normalisedName).first,
                  !units.contains(where: { $0.name == name })
            else { continue }
            units.append(PortionUnit(name: name, grams: (gramWeight / amount).rounded()))
        }
        return units
    }

    /// "cup, chopped" → "cup", "1 tablespoon" → "tbsp", "medium (7\" long)" → "medium piece".
    static func normalisedName(_ raw: String) -> String? {
        var name = raw.lowercased()
        if let cut = name.firstIndex(where: { $0 == "," || $0 == "(" }) { name = String(name[..<cut]) }
        name = name.replacingOccurrences(of: #"^[\d./\s]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let aliases = ["tablespoon": "tbsp", "tablespoons": "tbsp", "teaspoon": "tsp", "teaspoons": "tsp",
                       "cups": "cup", "slices": "slice", "pieces": "piece"]
        if let alias = aliases[name] { name = alias }
        if ["small", "medium", "large", "extra large", "jumbo"].contains(name) { name += " piece" }

        let skip = ["", "undetermined", "g", "gram", "grams", "oz", "lb", "kg", "serving", "quantity not specified"]
        guard !skip.contains(name), name.count <= 20, name.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        return name
    }

    // MARK: - Claude

    private static func claudeMeasures(for food: FoodCandidate, apiKey: String) async throws -> [PortionUnit] {
        let prompt = """
        Food: \(food.name)\(food.brand.map { " (\($0))" } ?? "")
        Give 2–3 household measures people really use for this food (for example cup, slice, piece, \
        medium piece, bowl), each with the typical weight in grams of ONE unit. If this food is ever \
        measured by the spoon (oils, butter, sugar, flour, sauces, spices, nut butters, powders, grains), \
        also include tbsp and tsp with this food's own weight. Use short singular names.
        Reply with JSON only, like {"measures":[{"unit":"cup","grams":125}]}
        """
        let body: [String: Any] = [
            "model": "claude-haiku-5-5",
            "max_tokens": 400,
            "system": "You give typical household measure weights for foods. Reply with JSON only.",
            "messages": [["role": "user", "content": prompt]],
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]]
        else { return [] }

        let text = content.compactMap { $0["text"] as? String }.joined()
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
              let reply = try JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any],
              let measures = reply["measures"] as? [[String: Any]]
        else { return [] }

        return measures.compactMap { raw in
            guard let name = (raw["unit"] as? String).flatMap(normalisedName),
                  let grams = (raw["grams"] as? Double) ?? (raw["grams"] as? Int).map(Double.init),
                  grams > 0, grams < 2000
            else { return nil }
            return PortionUnit(name: name, grams: grams)
        }
    }
}

/// Measures already found, saved in a small file so each food is only looked up once.
enum MeasureCache {
    private static var store: [String: [PortionUnit]] = load()

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "food-measures.json")
    }

    static func measures(for foodID: String) -> [PortionUnit]? {
        store[foodID]
    }

    static func save(_ measures: [PortionUnit], for foodID: String) {
        store[foodID] = measures
        guard let fileURL, let data = try? JSONEncoder().encode(store) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load() -> [String: [PortionUnit]] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: [PortionUnit]].self, from: data)) ?? [:]
    }
}
