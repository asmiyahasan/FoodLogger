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
    /// Bumped when the widget logged something while the app was away, so Today re-reads the database.
    @State private var dataVersion = 0
    @State private var seenWidgetChange = WidgetSync.lastExternalChange

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TodayView()
                    .id(dataVersion)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
        .keyboardDismissable()
        .sheet(isPresented: Binding(
            get: { hasCompletedOnboarding && !hasSeenTutorial },
            set: { if !$0 { hasSeenTutorial = true } }
        )) {
            TutorialView { hasSeenTutorial = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if WidgetSync.lastExternalChange > seenWidgetChange {
                    seenWidgetChange = WidgetSync.lastExternalChange
                    dataVersion += 1
                }
                Task {
                    await WaterReminders.reschedule(context: context)
                    if hasCompletedOnboarding { await AppExpiry.scheduleReminder() }
                }
            }
            if phase == .background {
                SettingsMirror.sync()
                WidgetSync.reloadNow()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self, WeightEntry.self], inMemory: true)
}
