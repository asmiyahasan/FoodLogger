import Foundation
import SwiftData

@Model
final class WaterEntry {
    var timestamp: Date = Date.now
    var millilitres: Double = 0

    init(millilitres: Double, timestamp: Date = .now) {
        self.millilitres = millilitres
        self.timestamp = timestamp
    }
}
