import Foundation

/// Ranks food names so the plain, common food comes first.
/// Typing "banana": "Banana, raw" → "Banana chip" → "Bread, banana".
nonisolated enum SearchRanking {
    /// Words that signal a processed or prepared form of a food.
    private static let processedWords: Set<String> = [
        "chip", "crisp", "juice", "bread", "cake", "muffin", "pie", "sauce", "beverage",
        "drink", "biscuit", "cookie", "soup", "powder", "bar", "cereal", "smoothie",
        "yoghurt", "yogurt", "ice", "confection", "jam", "spread", "snack", "lolly",
        "candy", "chocolate", "coated", "sweetened", "flavoured", "flavored", "dessert",
        "pudding", "pastry", "slice", "loaf", "cracker", "nectar", "cordial", "liqueur",
    ]

    /// Parts of a food or unusual kinds, ranked below the whole, common food.
    private static let partWords: Set<String> = [
        "yolk", "albumen", "skin", "separable", "human", "infant", "offal",
    ]

    /// Preparation words. If you don't type one, raw is preferred.
    private static let preparationWords: Set<String> = [
        "raw", "cooked", "boiled", "fried", "baked", "grilled", "roasted", "steamed",
        "poached", "scrambled", "dried", "canned", "frozen", "stewed", "microwaved",
        "barbecued", "casseroled", "toasted",
    ]

    static func terms(for query: String) -> [String] {
        words(in: query)
    }

    /// A score for a name (lower is better), or nil if it doesn't match.
    /// Every term must be a whole word in the name; the last term may also be
    /// the start of a word, so results appear while you're still typing.
    static func score(name: String, terms: [String]) -> Int? {
        guard let lastTerm = terms.last else { return nil }
        let normalisedName = normalise(name)
        let segments = normalisedName
            .split(separator: ",")
            .map { words(in: String($0)) }
            .filter { !$0.isEmpty }
        let allWords = segments.flatMap { $0 }

        var lastTermIsPartial = false
        for (index, term) in terms.enumerated() {
            if allWords.contains(term) { continue }
            if index == terms.count - 1, allWords.contains(where: { $0.hasPrefix(lastTerm) }) {
                lastTermIsPartial = true
                continue
            }
            return nil
        }

        // The first part of a database name is the food itself ("Banana" in "Banana, raw").
        let head = segments.first ?? []
        let headNounMatches: Bool = {
            guard let noun = head.first else { return false }
            return terms.enumerated().contains { pair in
                noun == pair.element || (pair.offset == terms.count - 1 && noun.hasPrefix(pair.element))
            }
        }()

        var score: Int
        if Set(head) == Set(terms) {
            score = 0            // "Banana, cavendish, raw"
        } else if headNounMatches {
            score = 100          // "Banana chip", or "Egg, fried" for "fried egg"
        } else if terms.allSatisfy({ head.contains($0) }) {
            score = 150          // "Cavendish banana"
        } else {
            score = 300          // "Bread, banana"
        }

        // Each extra qualifier makes it a bit more specific than you asked for.
        score += 10 * max(segments.count - 1, 0)

        let termSet = Set(terms)
        let extraWords = Set(allWords).subtracting(termSet)
        if !extraWords.isDisjoint(with: processedWords) {
            score += 60
        }
        if !extraWords.isDisjoint(with: partWords) {
            score += 10
        }
        if termSet.isDisjoint(with: preparationWords) {
            if allWords.contains("raw") {
                score -= 15
            } else if !extraWords.isDisjoint(with: preparationWords) {
                score += 20
            }
        }
        if lastTermIsPartial {
            score += 50
        }
        score += normalisedName.count / 8   // shorter names win ties
        return score
    }

    /// Re-orders results from any source and drops ones that don't really match.
    static func rank(_ candidates: [FoodCandidate], for query: String) -> [FoodCandidate] {
        let queryTerms = terms(for: query)
        guard !queryTerms.isEmpty else { return candidates }
        return candidates
            .enumerated()
            .compactMap { item -> (score: Int, order: Int, food: FoodCandidate)? in
                guard let score = score(name: item.element.name, terms: queryTerms) else { return nil }
                return (score, item.offset, item.element)
            }
            .sorted { ($0.score, $0.order) < ($1.score, $1.order) }
            .map(\.food)
    }

    static func normalise(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Lower-case words with simple plurals removed ("bananas" → "banana", "chips" → "chip").
    static func words(in text: String) -> [String] {
        normalise(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { singular(String($0)) }
    }

    private static func singular(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }   // berries → berry
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") {
            return String(word.dropLast())
        }
        return word
    }
}
