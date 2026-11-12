//
//  ContentView.swift
//  FoodLogger
//
//  Created by Asmiya Hasan on 12/11/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TodayView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
