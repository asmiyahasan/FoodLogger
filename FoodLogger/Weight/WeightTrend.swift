import Foundation

/// A day's weigh-in with the smoothed trend at that point.
nonisolated struct WeightPoint: Identifiable, Sendable {
    let date: Date      // start of the day
    let kg: Double      // what the scale said
    let trendKg: Double // smoothed
    var id: Date { date }
}

/// Daily weight jumps around by a kilo or more with water, salt and food in your gut.
/// The trend is an exponentially smoothed average (the "Hacker's Diet" method): each new day
/// moves it 10% of the way towards the scale reading, so one odd day barely shifts it.
nonisolated enum WeightTrend {
    static let dailySmoothing = 0.1

    /// One point per day (the latest weigh-in that day), oldest first.
    static func points(from readings: [WeightReading]) -> [WeightPoint] {
        let calendar = Calendar.current
        var latestPerDay: [Date: WeightReading] = [:]
        for reading in readings {
            let day = calendar.startOfDay(for: reading.date)
            if let existing = latestPerDay[day], existing.date > reading.date { continue }
            latestPerDay[day] = reading
        }

        var result: [WeightPoint] = []
        var trend: Double?
        var previousDay: Date?
        for day in latestPerDay.keys.sorted() {
            guard let kg = latestPerDay[day]?.kg else { continue }
            if let current = trend, let previousDay {
                // Missed days still count: a reading after a gap moves the trend further.
                let gap = Double(max(calendar.dateComponents([.day], from: previousDay, to: day).day ?? 1, 1))
                let weight = 1 - pow(1 - dailySmoothing, gap)
                trend = current + weight * (kg - current)
            } else {
                trend = kg
            }
            previousDay = day
            result.append(WeightPoint(date: day, kg: kg, trendKg: trend ?? kg))
        }
        return result
    }

    /// The most recent point on or before a day.
    static func point(onOrBefore day: Date, in points: [WeightPoint]) -> WeightPoint? {
        let end = Calendar.current.startOfDay(for: day)
        return points.last { $0.date <= end }
    }

    /// Trend change per week over the last 4 weeks (least-squares slope).
    /// Nil until there are at least 3 weigh-ins spanning a week.
    static func weeklyRate(_ points: [WeightPoint]) -> Double? {
        guard let last = points.last else { return nil }
        let windowStart = last.date.addingTimeInterval(-28 * 86_400)
        let recent = points.filter { $0.date >= windowStart }
        guard recent.count >= 3, let first = recent.first,
              last.date.timeIntervalSince(first.date) >= 7 * 86_400 else { return nil }

        let xs = recent.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = recent.map(\.trendKg)
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return nil }
        return numerator / denominator * 7
    }
}
