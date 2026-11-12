//
//  ContentView.swift
//  FoodLogger
//
//  Created by Asmiya Hasan on 12/11/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TodayView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
