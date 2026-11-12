import Foundation
import SwiftData
import WidgetKit

/// Keeps the home-screen widget in step with the app.
enum WidgetSync {
    static let kind = "FoodLoggerToday"

    /// Set by the widget when it logs something, so the app knows to refresh its lists.
    static let externalChangeKey = "widgetChangedAt"

    private static var pendingReload: Task<Void, Never>?

    /// Asks WidgetKit to redraw the widget. Calls close together are merged into one.
    static func reload() {
        pendingReload?.cancel()
        pendingReload = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Redraws straight away (used when the app is about to be suspended).
    static func reloadNow() {
        pendingReload?.cancel()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Records that the widget changed the database behind the app's back.
    static func markExternalChange() {
        AppGroup.settings.set(Date.now.timeIntervalSince1970, forKey: externalChangeKey)
    }

    static var lastExternalChange: Double {
        AppGroup.settings.double(forKey: externalChangeKey)
    }

    private static var observers: [NSObjectProtocol] = []

    /// App only: copy settings across and redraw the widget whenever data or settings change.
    static func startObserving() {
        guard observers.isEmpty else { return }
        SettingsMirror.sync()
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                if SettingsMirror.sync() { reload() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { reload() }
        })
    }
}

/// The app's settings live in its own UserDefaults (@AppStorage). The widget can't see those,
/// so the app copies them into the App Group whenever they change.
enum SettingsMirror {
    static var keys: [String] { SettingsKey.backedUp + [SettingsKey.hasCompletedOnboarding] }

    /// Copies changed values across. Returns true if anything changed.
    @discardableResult
    static func sync() -> Bool {
        let source = UserDefaults.standard
        let target = AppGroup.settings
        var changed = false
        for key in keys {
            let value = source.object(forKey: key)
            let current = target.object(forKey: key)
            if let value {
                if (value as? NSObject)?.isEqual(current) != true {
                    target.set(value, forKey: key)
                    changed = true
                }
            } else if current != nil {
                target.removeObject(forKey: key)
                changed = true
            }
        }
        return changed
    }
}
