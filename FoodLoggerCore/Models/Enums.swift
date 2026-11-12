import Foundation

nonisolated enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Guesses the meal from the time of day. The user can always change it.
    static func inferred(from date: Date, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

nonisolated enum MealStatus: String, Codable, Sendable {
    /// Captured, waiting for analysis (e.g. offline).
    case pending
    /// Analysed, waiting for the user to review.
    case ready
    /// Reviewed and counted in the day's totals.
    case logged
}

/// Where an item on a meal came from.
nonisolated enum ItemOrigin: String, Codable, Sendable {
    case voice, photo, inferred, user

    var label: String {
        switch self {
        case .voice: "from voice"
        case .photo: "from photo"
        case .inferred: "inferred"
        case .user: "entered by you"
        }
    }
}
