import Foundation

/// Nutrition values. Stored per 100 g on food items, summed for meals and days.
/// Energy is kept in kilocalories (converted for display), sodium in milligrams,
/// everything else in grams.
nonisolated struct Nutrients: Codable, Hashable, Sendable {
    var energyKcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var saturatedFat: Double = 0
    var carbs: Double = 0
    var sugars: Double = 0
    var fibre: Double = 0
    var sodiumMg: Double = 0

    static let zero = Nutrients()
    static let kilojoulesPerKilocalorie = 4.184

    var energyKJ: Double {
        get { energyKcal * Self.kilojoulesPerKilocalorie }
        set { energyKcal = newValue / Self.kilojoulesPerKilocalorie }
    }

    /// Values for a portion, e.g. `per100g.scaled(by: grams / 100)`.
    func scaled(by factor: Double) -> Nutrients {
        Nutrients(
            energyKcal: energyKcal * factor,
            protein: protein * factor,
            fat: fat * factor,
            saturatedFat: saturatedFat * factor,
            carbs: carbs * factor,
            sugars: sugars * factor,
            fibre: fibre * factor,
            sodiumMg: sodiumMg * factor
        )
    }

    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(
            energyKcal: lhs.energyKcal + rhs.energyKcal,
            protein: lhs.protein + rhs.protein,
            fat: lhs.fat + rhs.fat,
            saturatedFat: lhs.saturatedFat + rhs.saturatedFat,
            carbs: lhs.carbs + rhs.carbs,
            sugars: lhs.sugars + rhs.sugars,
            fibre: lhs.fibre + rhs.fibre,
            sodiumMg: lhs.sodiumMg + rhs.sodiumMg
        )
    }
}
