//
//  FoodLoggerApp.swift
//  FoodLogger
//
//  Created by Asmiya Hasan on 12/11/2026.
//

import SwiftUI
import SwiftData

@main
struct FoodLoggerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.turquoise)
        }
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self])
    }
}
