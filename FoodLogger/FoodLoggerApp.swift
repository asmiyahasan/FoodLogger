//
//  FoodLoggerApp.swift
//  FoodLogger
//
//  Created by Asmiya Hasan on 12/11/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FoodLoggerApp: App {
    let container: ModelContainer

    init() {
        container = SharedStore.container
        // Lets reminder buttons (+250 ml) log water straight into the database.
        NotificationHandler.shared.container = container
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.turquoise)
        }
        .modelContainer(container)
    }
}
