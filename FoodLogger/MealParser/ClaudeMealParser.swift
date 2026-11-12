import Foundation

/// One item Claude found in a meal. `food` is a real database entry, or nil if none matched.
nonisolated struct ParsedMealItem: Sendable {
    var name: String
    var grams: Double
    var food: FoodCandidate?
    var origin: ItemOrigin
    var confidence: Double
    var note: String
    /// Set for ingredients estimated from a recipe ("Beef tehari").
    var dish: String
}

nonisolated enum MealParserError: LocalizedError {
    case missingKey
    case api(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .missingKey: "Add your Claude API key to Secrets.plist (or Settings) first."
        case .api(let message): "Claude couldn't analyse the meal: \(message)"
        case .noResult: "Claude didn't finish the analysis. Try again, or add items manually."
        }
    }
}

/// Turns a meal photo + spoken description into items matched to database foods.
/// Claude only picks foods (by ID) and estimates grams; every nutrient value comes
/// from the databases through the search_foods tool.
nonisolated struct ClaudeMealParser: Sendable {
    let apiKey: String
    let engine: FoodSearchEngine
    var model = "claude-sonnet-5-5"
    var maxRounds = 8
    let onProgress: @Sendable (String) -> Void

    func parse(imageJPEG: Data?, transcript: String) async throws -> [ParsedMealItem] {
        var userContent: [[String: Any]] = []
        if let imageJPEG {
            userContent.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": imageJPEG.base64EncodedString()],
            ])
        }
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        userContent.append([
            "type": "text",
            "text": spoken.isEmpty
                ? "No description was given. Identify the meal from the photo."
                : "The user's description of this meal: \"\(spoken)\"",
        ])

        var found: [String: FoodCandidate] = [:]
        let usual = engine.savedFoods.sorted { $0.timesUsed > $1.timesUsed }.prefix(25)
        if !usual.isEmpty {
            for food in usual { found[food.candidate.id] = food.candidate }
            let lines = usual.map { food -> String in
                let brand = food.candidate.brand.map { " (\($0))" } ?? ""
                let usualAmount = food.candidate.servingGrams.map { ", usually \(Int($0.rounded())) g" } ?? ""
                let otherNames = food.aliases.isEmpty ? "" : ", also called: \(food.aliases.prefix(3).joined(separator: ", "))"
                return "- \(food.candidate.name)\(brand)\(usualAmount)\(otherNames). food_id \(food.candidate.id)"
            }
            userContent.append([
                "type": "text",
                "text": "Foods this user logs often. If an item plausibly matches one, use its food_id directly and its usual amount, unless the photo or description says otherwise:\n" + lines.joined(separator: "\n"),
            ])
        }

        var messages: [[String: Any]] = [["role": "user", "content": userContent]]
        var nudged = false

        onProgress("Reading the meal…")
        for _ in 0..<maxRounds {
            let response = try await send(messages)
            guard let content = response["content"] as? [[String: Any]] else { throw MealParserError.noResult }
            // Replay the assistant turn exactly as received (required for thinking blocks).
            messages.append(["role": "assistant", "content": content])

            let toolUses = content.filter { $0["type"] as? String == "tool_use" }
            if toolUses.isEmpty {
                guard !nudged else { break }
                nudged = true
                messages.append(["role": "user", "content": "Please call submit_meal with all the items now."])
                continue
            }

            var toolResults: [[String: Any]] = []
            for use in toolUses {
                let id = use["id"] as? String ?? ""
                let input = use["input"] as? [String: Any] ?? [:]
                switch use["name"] as? String {
                case "submit_meal":
                    return Self.items(from: input, found: found)
                case "search_foods":
                    let query = (input["query"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                    onProgress("Looking up \(query)…")
                    let results = await engine.search(query)
                    for result in results { found[result.id] = result }
                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": id,
                        "content": Self.describe(results),
                    ])
                default:
                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": id,
                        "content": "Unknown tool.",
                        "is_error": true,
                    ])
                }
            }
            messages.append(["role": "user", "content": toolResults])
            onProgress("Estimating portions…")
        }
        throw MealParserError.noResult
    }

    // MARK: - API call

    private func send(_ messages: [[String: Any]]) async throws -> [String: Any] {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": Self.systemPrompt,
            "tools": Self.tools,
            "tool_choice": ["type": "auto"],
            // Sonnet 5.5: no up-front thinking; keeps each meal fast and cheap.
            "thinking": ["type": "between_tools"],
            "output_config": ["effort": "medium"],
            "messages": messages,
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            throw MealParserError.api(message)
        }
        return json
    }

    // MARK: - Tool results

    /// Search results as compact JSON for Claude: IDs and per-100 g values to choose from.
    private static func describe(_ results: [FoodCandidate]) -> String {
        guard !results.isEmpty else { return "No matches. Try a shorter or more generic name." }
        let rows: [[String: Any]] = results.map { food in
            var row: [String: Any] = [
                "food_id": food.id,
                "name": food.name,
                "source": food.source.shortLabel,
                "detail": food.detail,
                "per_100g": [
                    "kcal": round(food.per100g.energyKcal),
                    "protein_g": round(food.per100g.protein * 10) / 10,
                    "fat_g": round(food.per100g.fat * 10) / 10,
                    "carbs_g": round(food.per100g.carbs * 10) / 10,
                ],
            ]
            if let serving = food.servingGrams { row["typical_serving_g"] = serving }
            return row
        }
        let data = (try? JSONSerialization.data(withJSONObject: rows)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func items(from input: [String: Any], found: [String: FoodCandidate]) -> [ParsedMealItem] {
        let raw = input["items"] as? [[String: Any]] ?? []
        return raw.map { item in
            let foodID = item["food_id"] as? String ?? ""
            return ParsedMealItem(
                name: (item["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Item",
                grams: max((item["grams"] as? Double) ?? 0, 0),
                food: found[foodID],   // an ID Claude didn't get from a search is treated as no match
                origin: ItemOrigin(rawValue: item["origin"] as? String ?? "") ?? .photo,
                confidence: min(max((item["confidence"] as? Double) ?? 0.5, 0), 1),
                note: item["note"] as? String ?? "",
                dish: (item["dish"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            )
        }
    }

    // MARK: - Prompt and tools

    private static let systemPrompt = """
    You log meals for a personal nutrition tracker used in Australia. You get a photo of a meal \
    and/or the user's spoken description of it.

    How to work:
    - The description is authoritative for which foods are present and how many. Use the photo to \
    estimate portion sizes and to spot items the user didn't mention (for example bread in a sandwich).
    - For every item, call search_foods and pick the best match by its food_id. You can call it for \
    several items at once. Use short, generic search terms ("egg fried", "turkey slices", \
    "mayonnaise"); include a brand only if the user said one.
    - If a search returns nothing useful, search again with one simpler word ("almond" rather than \
    "flaked almonds", "sugar icing" rather than "icing sugar dusting").
    - For composite foods (an almond croissant, a burger), use one entry if a matching one exists. \
    If only a plainer version exists ("Croissant, plain"), you may add the clearly visible extras \
    as separate items, but never add parts already included in the chosen entry.
    - Mixed and home-cooked dishes (curries, biryani, tehari, polao, khichuri, dal, haleem, \
    nihari, korma and similar from any cuisine) are rarely in the databases. Search for the whole \
    dish first, including the user's saved foods. If there's no close match, estimate a typical \
    home-style recipe for the portion shown and log its main ingredients as separate items: the \
    cooked staple (rice, noodles, bread), the protein, vegetables, and the cooking fat. Give every \
    ingredient the same "dish" name (e.g. "Beef tehari") so they're shown together. Grams must \
    add up to the whole portion. Use cooked forms (cooked rice, cooked beef).
    - Always list the cooking fat (oil or ghee) as its own ingredient, since it's where much of \
    the energy in these dishes is. Mark it origin "inferred" with a note such as "How much ghee \
    or oil? Home-style tehari often uses 1–2 tbsp per plate."
    - Recipe estimates get confidence 0.6 or less, as amounts vary between cooks.
    - Never invent nutrition values. You only choose food_ids from search results and estimate grams. \
    If nothing suitable is found after two searches, submit the item with food_id "".
    - Estimate grams for the whole amount eaten, using typical weights unless the photo suggests \
    otherwise (1 large egg ≈ 50 g, 1 slice of bread ≈ 35 g, 1 slice of processed cheese ≈ 20 g, \
    1 slice of deli turkey ≈ 20 g, 1 tablespoon of a sauce or spread ≈ 15 g).
    - Prefer prepared forms that match the meal (fried egg, boiled rice) over raw ones.
    - Only add hidden items when strongly implied, such as about 5 g of oil for something fried. \
    Mark them origin "inferred", confidence 0.5 or less, and put a short question in note \
    ("Fried in oil?").
    - origin: "voice" if the user mentioned it, "photo" if only seen in the photo, "inferred" otherwise.
    - confidence: 0 to 1, covering both the food match and the portion estimate.
    - Finish by calling submit_meal exactly once with every item.
    """

    private static var tools: [[String: Any]] {
        [
        [
            "name": "search_foods",
            "description": "Search the user's saved foods, the Australian Food Composition Database, Open Food Facts and USDA. Returns candidates with food_id, name, source and nutrients per 100 g.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "Short food name, e.g. \"egg fried\" or \"mayonnaise\"."],
                ],
                "required": ["query"],
            ],
        ],
        [
            "name": "submit_meal",
            "description": "Submit the final list of items in the meal. Call once, at the end.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "items": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string", "description": "Short display name, e.g. \"Fried egg\"."],
                                "food_id": ["type": "string", "description": "food_id from search results, or \"\" if no match."],
                                "grams": ["type": "number", "description": "Estimated grams eaten."],
                                "origin": ["type": "string", "enum": ["voice", "photo", "inferred"]],
                                "confidence": ["type": "number", "description": "0 to 1."],
                                "note": ["type": "string", "description": "Optional short question or caveat for the user."],
                                "dish": ["type": "string", "description": "For ingredients estimated from a recipe: the dish they belong to, e.g. \"Beef tehari\". Empty otherwise."],
                            ],
                            "required": ["name", "food_id", "grams", "origin", "confidence"],
                        ],
                    ],
                ],
                "required": ["items"],
            ],
        ],
        ]
    }
}
