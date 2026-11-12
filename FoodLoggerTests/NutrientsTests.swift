import Foundation
import Testing
@testable import FoodLogger

struct NutrientsTests {
    @Test func scalingForAPortion() {
        let per100g = Nutrients(energyKcal: 200, protein: 10, fat: 5)
        let portion = per100g.scaled(by: 0.5)
        #expect(portion.energyKcal == 100)
        #expect(portion.protein == 5)
        #expect(portion.fat == 2.5)
    }

    @Test func addingTotals() {
        let total = Nutrients(energyKcal: 100, fibre: 2) + Nutrients(energyKcal: 50, fibre: 3)
        #expect(total.energyKcal == 150)
        #expect(total.fibre == 5)
    }

    @Test func kilojouleConversion() {
        #expect(abs(EnergyUnit.kJ.value(fromKcal: 100) - 418.4) < 0.0001)
        #expect(abs(EnergyUnit.kJ.kcal(from: 418.4) - 100) < 0.0001)
    }

    @Test func mealTypeFromTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 19))!
        #expect(MealType.inferred(from: morning, calendar: calendar) == .breakfast)
        #expect(MealType.inferred(from: evening, calendar: calendar) == .dinner)
    }

    @Test func macrosFromCalories() {
        let goals = MacroGoals.from(energyKcal: 2000, proteinPercent: 20, fatPercent: 30)
        #expect(goals.protein == 100)   // 400 kcal / 4
        #expect(goals.carbs == 250)     // 1000 kcal / 4
        #expect(abs(goals.fat - 66.67) < 0.01) // 600 kcal / 9
    }
}
