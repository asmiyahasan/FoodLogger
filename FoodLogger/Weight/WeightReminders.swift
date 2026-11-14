import Foundation
import SwiftData
import SwiftUI
import UserNotifications

/// Reminds you to weigh in every day, every 2 or 3 days, or once a week, at a time you choose.
/// The count restarts from your latest weigh-in, so a reminder is skipped if you've already weighed in.
/// Rescheduled when the app opens, when you log or delete a weigh-in, and when the settings change.
enum WeightReminders {
    static let identifierPrefix = "weight-reminder-"
    private static let maxScheduled = 8

    enum Frequency: Int, CaseIterable, Identifiable {
        case daily = 1, everyTwoDays = 2, everyThreeDays = 3, weekly = 7

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .daily: "Every day"
            case .everyTwoDays: "Every 2 days"
            case .everyThreeDays: "Every 3 days"
            case .weekly: "Every week"
            }
        }
    }

    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKey.weightRemindersOn) else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let frequency = Frequency(rawValue: defaults.object(forKey: SettingsKey.weightReminderDays) as? Int
                                  ?? GoalDefaults.weightReminderDays) ?? .daily
        let minutes = defaults.object(forKey: SettingsKey.weightReminderMinutes) as? Int ?? GoalDefaults.weightReminderMinutes
        let weekday = defaults.object(forKey: SettingsKey.weightReminderWeekday) as? Int ?? GoalDefaults.weightReminderWeekday
        let unit = WeightUnit(rawValue: defaults.string(forKey: SettingsKey.weightUnit) ?? "") ?? .kg

        let entries = (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.timestamp)]))) ?? []
        let latest = WeightTrend.points(from: entries.map(\.reading)).last

        let content = UNMutableNotificationContent()
        content.title = "Time to weigh in"
        content.body = latest.map { "Your trend is \(unit.format(kg: $0.trendKg)). A quick weigh-in keeps it accurate." }
            ?? "Log your weight to start seeing your trend."
        content.sound = .default
        content.categoryIdentifier = NotificationHandler.weightCategoryID

        let calendar = Calendar.current
        for slot in slots(frequency: frequency, minutes: minutes, weekday: weekday, lastWeighIn: latest?.date) {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = identifierPrefix + String(Int(slot.timeIntervalSince1970))
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// When the next reminders go off.
    /// - lastWeighIn: the day of your latest weigh-in (start of day), if any.
    static func slots(
        frequency: Frequency,
        minutes: Int,
        weekday: Int,
        lastWeighIn: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: now)
        func time(on day: Date) -> Date? { calendar.date(byAdding: .minute, value: minutes, to: day) }
        func add(_ days: Int, to day: Date) -> Date {
            calendar.date(byAdding: .day, value: days, to: day) ?? day.addingTimeInterval(Double(days) * 86_400)
        }

        var result: [Date] = []
        switch frequency {
        case .weekly:
            var day = today
            for _ in 0..<70 where result.count < maxScheduled {
                defer { day = add(1, to: day) }
                guard calendar.component(.weekday, from: day) == weekday,
                      let slot = time(on: day), slot > now else { continue }
                // Already weighed in during the week leading up to this reminder: skip it.
                if let lastWeighIn, lastWeighIn >= add(-6, to: day) { continue }
                result.append(slot)
            }
        default:
            let step = frequency.rawValue
            // Next one is due `step` days after your last weigh-in (or today if you've never weighed in).
            var day = lastWeighIn.map { add(step, to: $0) } ?? today
            if day < today { day = today }   // overdue: remind today
            // Today's time already passed: first reminder tomorrow, then every `step` days.
            if let first = time(on: day), first <= now { day = add(1, to: day) }
            for _ in 0..<maxScheduled {
                if let slot = time(on: day) { result.append(slot) }
                day = add(step, to: day)
            }
        }
        return result
    }
}

/// The weigh-in reminder settings, shown in Goals under Weight.
struct WeightReminderSection: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.weightRemindersOn) private var isOn = false
    @AppStorage(SettingsKey.weightReminderDays) private var days = GoalDefaults.weightReminderDays
    @AppStorage(SettingsKey.weightReminderMinutes) private var minutes = GoalDefaults.weightReminderMinutes
    @AppStorage(SettingsKey.weightReminderWeekday) private var weekday = GoalDefaults.weightReminderWeekday
    @State private var notificationsBlocked = false

    var body: some View {
        Section {
            Toggle("Weigh-in reminder", isOn: $isOn)
            if isOn {
                Picker("How often", selection: $days) {
                    ForEach(WeightReminders.Frequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency.rawValue)
                    }
                }
                if days == WeightReminders.Frequency.weekly.rawValue {
                    Picker("On", selection: $weekday) {
                        ForEach(Self.weekdays) { day in
                            Text(day.name).tag(day.number)
                        }
                    }
                }
                DatePicker("At", selection: time, displayedComponents: .hourAndMinute)
            }
        } footer: {
            if notificationsBlocked {
                Text("Notifications are off for FoodLogger. Turn them on in Settings → Notifications → FoodLogger.")
                    .foregroundStyle(Theme.deepOrangeText)
            } else {
                Text("Skipped if you've already weighed in. Tap the reminder to log straight away.")
            }
        }
        .onChange(of: isOn) { _, newValue in
            Task {
                if newValue, !(await WaterReminders.requestPermission()) {
                    isOn = false
                    notificationsBlocked = true
                    return
                }
                notificationsBlocked = false
                await WeightReminders.reschedule(context: context)
            }
        }
        .onChange(of: days) { refresh() }
        .onChange(of: minutes) { refresh() }
        .onChange(of: weekday) { refresh() }
    }

    /// The reminder time as a Date for the picker, stored as minutes after midnight.
    private var time: Binding<Date> {
        Binding(
            get: { Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: .now)) ?? .now },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 30)
            }
        )
    }

    private func refresh() {
        Task { await WeightReminders.reschedule(context: context) }
    }

    /// Weekdays in the order of the device's calendar (Monday first in Australia).
    private static var weekdays: [Weekday] {
        let calendar = Calendar.current
        let names = calendar.weekdaySymbols
        return (0..<7).map { offset in
            let number = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return Weekday(number: number, name: names[number - 1])
        }
    }

    private struct Weekday: Identifiable {
        let number: Int   // Calendar weekday: 1 = Sunday
        let name: String
        var id: Int { number }
    }
}
