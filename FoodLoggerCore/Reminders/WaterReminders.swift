import Foundation
import SwiftData
import UserNotifications

/// Schedules water reminders that only fire when you're behind pace for the day.
/// Rescheduled whenever water is logged, settings change, or the app opens.
enum WaterReminders {
    static let identifierPrefix = "water-reminder-"
    static let categoryID = "WATER_REMINDER"
    static let logFirstAction = "LOG_WATER_1"
    static let logSecondAction = "LOG_WATER_2"
    private static let daysAhead = 7

    /// Asks for notification permission. Returns whether reminders can be shown.
    static func requestPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let defaults = AppGroup.settings
        guard defaults.bool(forKey: SettingsKey.waterRemindersOn) else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let goal = defaults.object(forKey: SettingsKey.goalWaterMl) as? Double ?? GoalDefaults.waterMl
        let quick1 = defaults.object(forKey: SettingsKey.quickWater1) as? Double ?? GoalDefaults.quickWater1
        let quick2 = defaults.object(forKey: SettingsKey.quickWater2) as? Double ?? GoalDefaults.quickWater2
        let startHour = defaults.object(forKey: SettingsKey.waterReminderStartHour) as? Int ?? GoalDefaults.reminderStartHour
        let endHour = defaults.object(forKey: SettingsKey.waterReminderEndHour) as? Int ?? GoalDefaults.reminderEndHour
        let interval = defaults.object(forKey: SettingsKey.waterReminderIntervalHours) as? Double ?? GoalDefaults.reminderIntervalHours
        guard goal > 0, endHour > startHour, interval > 0 else { return }

        registerCategory(quick1: quick1, quick2: quick2)

        let calendar = Calendar.current
        let now = Date.now
        let todayTotal = totalToday(context: context)

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)),
                  let windowStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
                  let windowEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)
            else { continue }

            if dayOffset == 0 && todayTotal >= goal { continue }   // goal reached: no more today

            var slot = windowStart.addingTimeInterval(interval * 3600)
            while slot <= windowEnd {
                defer { slot = slot.addingTimeInterval(interval * 3600) }
                guard slot > now else { continue }

                let content = UNMutableNotificationContent()
                content.categoryIdentifier = categoryID
                content.sound = .default
                content.title = "Water check"

                if dayOffset == 0 {
                    // Where you should be by this time if you drink steadily through the window.
                    let fraction = slot.timeIntervalSince(windowStart) / windowEnd.timeIntervalSince(windowStart)
                    let expected = goal * min(fraction, 1)
                    if todayTotal >= expected { continue }   // still on pace at that time: skip
                    content.body = "You're at \(litresText(todayTotal)) of \(litresText(goal)) L. A glass now keeps you on track."
                } else {
                    content.body = "A glass of water now keeps you on track for \(litresText(goal)) L today."
                }

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let id = identifierPrefix + String(Int(slot.timeIntervalSince1970))
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    /// Used by the widget: drops today's pending reminders that are no longer needed
    /// after water was logged outside the app. The app does a full reschedule when it next opens.
    static func pruneAfterExternalLog(context: ModelContext) async {
        let defaults = AppGroup.settings
        let goal = defaults.object(forKey: SettingsKey.goalWaterMl) as? Double ?? GoalDefaults.waterMl
        let startHour = defaults.object(forKey: SettingsKey.waterReminderStartHour) as? Int ?? GoalDefaults.reminderStartHour
        let endHour = defaults.object(forKey: SettingsKey.waterReminderEndHour) as? Int ?? GoalDefaults.reminderEndHour
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard goal > 0, endHour > startHour,
              let windowStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: today),
              let windowEnd = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: today)
        else { return }

        let total = totalToday(context: context)
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { id in
                guard id.hasPrefix(identifierPrefix),
                      let seconds = Double(id.dropFirst(identifierPrefix.count)) else { return false }
                let slot = Date(timeIntervalSince1970: seconds)
                guard calendar.isDate(slot, inSameDayAs: today) else { return false }
                let fraction = slot.timeIntervalSince(windowStart) / windowEnd.timeIntervalSince(windowStart)
                return total >= goal * min(max(fraction, 0), 1)
            }
        center.removePendingNotificationRequests(withIdentifiers: stale)
    }

    private static func registerCategory(quick1: Double, quick2: Double) {
        func title(_ ml: Double) -> String { "+\(Int(ml)) ml" }
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [
                UNNotificationAction(identifier: logFirstAction, title: title(quick1), options: []),
                UNNotificationAction(identifier: logSecondAction, title: title(quick2), options: []),
            ],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func totalToday(context: ModelContext) -> Double {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { entry in entry.timestamp >= start && entry.timestamp < end }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.millilitres }
    }
}

/// Handles taps on reminder actions (+250 ml / +500 ml) without opening the app.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    var container: ModelContainer?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        await MainActor.run {
            NotificationHandler.shared.handle(action: action)
        }
    }

    /// Show reminders even when the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func handle(action: String) {
        guard let container else { return }
        let defaults = AppGroup.settings
        let millilitres: Double
        switch action {
        case WaterReminders.logFirstAction:
            millilitres = defaults.object(forKey: SettingsKey.quickWater1) as? Double ?? GoalDefaults.quickWater1
        case WaterReminders.logSecondAction:
            millilitres = defaults.object(forKey: SettingsKey.quickWater2) as? Double ?? GoalDefaults.quickWater2
        default:
            return
        }
        let context = container.mainContext
        context.insert(WaterEntry(millilitres: millilitres))
        try? context.save()
        WidgetSync.reload()
        Task { await WaterReminders.reschedule(context: context) }
    }
}
