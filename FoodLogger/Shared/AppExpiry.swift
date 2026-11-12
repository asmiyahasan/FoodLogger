import Foundation
import UserNotifications

/// Free developer accounts sign apps for 7 days. This reads the expiry date from the
/// app's own signing profile and sends a reminder the day before.
enum AppExpiry {
    static let notificationID = "app-expiry"

    /// When this install stops opening. Nil in the simulator or on a Mac build.
    static let expiryDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }()

    /// True in the last two days before expiry.
    static var isExpiringSoon: Bool {
        guard let expiryDate else { return false }
        return expiryDate.timeIntervalSinceNow < 2 * 86_400
    }

    static func scheduleReminder() async {
        guard let expiryDate else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { return }

        let warnAt = expiryDate.addingTimeInterval(-86_400)
        guard warnAt > .now else { return }   // already in the last day: the Today banner covers it

        let content = UNMutableNotificationContent()
        content.title = "FoodLogger needs a refresh"
        var body = "This install stops opening \(expiryDate.formatted(.dateTime.weekday(.wide).hour().minute())). Open Xcode and press Run to renew it."
        if BackupService.backupIsDue {
            body += " It's a good moment to back up your data too."
        }
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: warnAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }
}
