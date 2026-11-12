import Foundation

/// Learns how your real portions compare with Claude's photo estimates, per food and overall,
/// and adjusts new estimates to match. Only photo-estimated amounts are adjusted or learned from:
/// amounts you say out loud are taken as given.
enum PortionLearning {
    static let samplesNeededPerFood = 2
    static let samplesNeededOverall = 5

    // MARK: Overall

    static var overallFactor: Double {
        UserDefaults.standard.object(forKey: SettingsKey.portionCorrectionAll) as? Double ?? 1
    }

    static var overallSamples: Int {
        UserDefaults.standard.object(forKey: SettingsKey.portionCorrectionSamples) as? Int ?? 0
    }

    static func recordOverall(_ observed: Double) {
        let defaults = UserDefaults.standard
        defaults.set(blend(overallFactor, samples: overallSamples, observed: observed), forKey: SettingsKey.portionCorrectionAll)
        defaults.set(overallSamples + 1, forKey: SettingsKey.portionCorrectionSamples)
    }

    // MARK: Per food

    static func record(_ observed: Double, on food: UserFood) {
        food.portionCorrection = blend(food.portionCorrection, samples: food.correctionSamples, observed: observed)
        food.correctionSamples += 1
    }

    /// final ÷ estimate, capped so one unusual edit can't skew things.
    static func observedRatio(final: Double, estimate: Double) -> Double? {
        guard estimate > 0, final > 0 else { return nil }
        return min(max(final / estimate, 0.25), 4)
    }

    /// Recent meals count more (30% weight), so it adapts if your habits change.
    private static func blend(_ current: Double, samples: Int, observed: Double) -> Double {
        samples == 0 ? observed : current * 0.7 + observed * 0.3
    }

    // MARK: Applying

    /// Adjusts photo estimates using your history. Returns the drafts with a note on each change.
    static func apply(to drafts: [DraftItem], savedFoods: [UserFood]) -> [DraftItem] {
        var result = drafts
        let overall = overallSamples >= samplesNeededOverall ? overallFactor : 1

        // Single items estimated from the photo.
        for index in result.indices where result[index].dish.isEmpty && result[index].origin == .photo {
            let draft = result[index]
            let food = savedFoods.first { $0.foodID == draft.foodID || (!draft.foodID.isEmpty && $0.basedOnFoodID == draft.foodID) }
            let factor = (food?.correctionSamples ?? 0) >= samplesNeededPerFood ? (food?.portionCorrection ?? 1) : overall
            scale(&result[index], by: factor)
        }

        // Estimated dishes learn and adjust as a whole.
        let dishes = Set(result.map(\.dish)).filter { !$0.isEmpty }
        for dish in dishes {
            let food = savedFoods.first { $0.name.localizedCaseInsensitiveCompare(dish) == .orderedSame }
            let factor = (food?.correctionSamples ?? 0) >= samplesNeededPerFood ? (food?.portionCorrection ?? 1) : overall
            guard abs(factor - 1) >= 0.05 else { continue }
            for index in result.indices where result[index].dish == dish {
                result[index].grams = (result[index].grams * factor).rounded()
            }
            if let first = result.firstIndex(where: { $0.dish == dish }), result[first].note.isEmpty {
                result[first].note = adjustmentNote(factor, for: dish)
            }
        }
        return result
    }

    private static func scale(_ draft: inout DraftItem, by factor: Double) {
        guard abs(factor - 1) >= 0.05 else { return }
        draft.grams = (draft.grams * factor).rounded()
        if draft.note.isEmpty {
            draft.note = adjustmentNote(factor, for: nil)
        }
    }

    private static func adjustmentNote(_ factor: Double, for dish: String?) -> String {
        let percent = Int(((factor - 1) * 100).rounded())
        let change = percent > 0 ? "+\(percent)%" : "\(percent)%"
        return dish == nil
            ? "Adjusted \(change) to match your usual portions."
            : "\(dish!) adjusted \(change) to match your usual portions."
    }

    /// Forget everything learned.
    static func reset(savedFoods: [UserFood]) {
        UserDefaults.standard.removeObject(forKey: SettingsKey.portionCorrectionAll)
        UserDefaults.standard.removeObject(forKey: SettingsKey.portionCorrectionSamples)
        for food in savedFoods {
            food.portionCorrection = 1
            food.correctionSamples = 0
        }
    }
}
