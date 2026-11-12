import AppIntents
import SwiftData
import Foundation

// MARK: - Log water

enum WaterAmount: Int, AppEnum {
    case ml250 = 250
    case ml330 = 330
    case ml500 = 500
    case ml750 = 750
    case ml1000 = 1000

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Water amount"
    static let caseDisplayRepresentations: [WaterAmount: DisplayRepresentation] = [
        .ml250: DisplayRepresentation(title: "250 ml", synonyms: ["a glass", "250 millilitres"]),
        .ml330: DisplayRepresentation(title: "330 ml", synonyms: ["a can", "330 millilitres"]),
        .ml500: DisplayRepresentation(title: "500 ml", synonyms: ["half a litre", "a bottle", "500 millilitres"]),
        .ml750: DisplayRepresentation(title: "750 ml", synonyms: ["750 millilitres"]),
        .ml1000: DisplayRepresentation(title: "1 litre", synonyms: ["a litre", "1000 ml"]),
    ]
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log water"
    static let description = IntentDescription("Adds water to today's log.")

    @Parameter(title: "Amount", default: .ml250)
    var amount: WaterAmount

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        context.insert(WaterEntry(millilitres: Double(amount.rawValue)))
        try context.save()
        await WaterReminders.reschedule(context: context)

        let total = WaterReminders.totalToday(context: context)
        let goal = DailySnapshot.waterGoalMl
        let message = total >= goal
            ? "Logged \(amount.rawValue) ml. You've reached your \(litresText(goal)) litre goal. Nice!"
            : "Logged \(amount.rawValue) ml. You're at \(litresText(total)) of \(litresText(goal)) litres."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Check progress

struct CaloriesLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "Calories left today"
    static let description = IntentDescription("Tells you how much energy you have left today and your protein so far.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let eaten = DailySnapshot.eatenToday(context: SharedStore.container.mainContext)
        let unit = DailySnapshot.energyUnit
        let goal = DailySnapshot.energyGoalKcal
        let remaining = goal - eaten.energyKcal
        let protein = DailySnapshot.macroGoals.protein

        let energyPart = remaining >= 0
            ? "You have \(unit.format(kcal: remaining)) left of your \(unit.format(kcal: goal)) goal."
            : "You're \(unit.format(kcal: -remaining)) over your \(unit.format(kcal: goal)) goal."
        let proteinPart = "Protein so far: \(Int(eaten.protein.rounded())) of \(Int(protein.rounded())) grams."
        return .result(dialog: IntentDialog(stringLiteral: "\(energyPart) \(proteinPart)"))
    }
}

struct WaterProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Water today"
    static let description = IntentDescription("Tells you how much water you've had today.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let total = WaterReminders.totalToday(context: SharedStore.container.mainContext)
        let goal = DailySnapshot.waterGoalMl
        let message = total >= goal
            ? "You've had \(litresText(total)) litres today. Goal reached!"
            : "You've had \(litresText(total)) of \(litresText(goal)) litres today."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Open the camera

struct SnapMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Snap a meal"
    static let description = IntentDescription("Opens FoodLogger ready to photograph and describe a meal.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set("capture", forKey: SettingsKey.pendingLaunchAction)
        return .result()
    }
}

// MARK: - Siri phrases

struct FoodLoggerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log \(\.$amount) of water in \(.applicationName)",
                "Add \(\.$amount) of water to \(.applicationName)",
            ],
            shortTitle: "Log water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CaloriesLeftIntent(),
            phrases: [
                "How many calories do I have left in \(.applicationName)",
                "Calories left in \(.applicationName)",
                "Check my day in \(.applicationName)",
            ],
            shortTitle: "Calories left",
            systemImageName: "flame"
        )
        AppShortcut(
            intent: WaterProgressIntent(),
            phrases: [
                "How much water have I had in \(.applicationName)",
                "Water today in \(.applicationName)",
            ],
            shortTitle: "Water today",
            systemImageName: "drop"
        )
        AppShortcut(
            intent: SnapMealIntent(),
            phrases: [
                "Snap a meal in \(.applicationName)",
                "Log a meal in \(.applicationName)",
            ],
            shortTitle: "Snap a meal",
            systemImageName: "camera.fill"
        )
    }
}
