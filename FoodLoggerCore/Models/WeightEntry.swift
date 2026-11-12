import Foundation
import SwiftData

/// One weigh-in. Always stored in kilograms; shown in the user's unit.
@Model
final class WeightEntry {
    var timestamp: Date = Date.now
    var kilograms: Double = 0

    init(kilograms: Double, timestamp: Date = .now) {
        self.kilograms = kilograms
        self.timestamp = timestamp
    }

    var reading: WeightReading { WeightReading(date: timestamp, kg: kilograms) }
}

/// A plain copy of a weigh-in, safe to pass to the trend maths.
nonisolated struct WeightReading: Sendable {
    let date: Date
    let kg: Double
}
