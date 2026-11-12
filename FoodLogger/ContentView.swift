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
    @AppStorage(SettingsKey.hasSeenTutorial) private var hasSeenTutorial = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

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
        .sheet(isPresented: Binding(
            get: { hasCompletedOnboarding && !hasSeenTutorial },
            set: { if !$0 { hasSeenTutorial = true } }
        )) {
            TutorialView { hasSeenTutorial = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await WaterReminders.reschedule(context: context)
                    if hasCompletedOnboarding { await AppExpiry.scheduleReminder() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
