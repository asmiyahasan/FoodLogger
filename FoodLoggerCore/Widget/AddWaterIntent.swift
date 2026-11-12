import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// The widget's "+250 ml" button. Runs without opening the app.
struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Add water"
    static let description = IntentDescription("Adds water to today's log from the widget.")
    static let isDiscoverable = false

    @Parameter(title: "Millilitres", default: 250)
    var millilitres: Int

    init() {}

    init(millilitres: Int) {
        self.millilitres = millilitres
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.container.mainContext
        context.insert(WaterEntry(millilitres: Double(millilitres)))
        try context.save()

        if AppGroup.isExtension {
            WidgetSync.markExternalChange()
            await WaterReminders.pruneAfterExternalLog(context: context)
        } else {
            await WaterReminders.reschedule(context: context)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
