import SwiftUI

/// Weight on the Today screen: the day's weigh-in, the trend, and a button to log.
struct WeightCard: View {
    /// The weigh-in on this day, or the latest one before it.
    let point: WeightPoint?
    let loggedOnDay: Bool
    let weeklyRate: Double?
    /// 0 means no goal.
    let goalKg: Double
    let unit: WeightUnit
    let isToday: Bool
    let log: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.deepOrangeText)
                Spacer()
                if let point {
                    Text(unit.format(kg: point.kg))
                        .font(.rounded(.subheadline))
                        .foregroundStyle(loggedOnDay ? Color.primary : Color.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: log) {
                Text(buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Theme.orange)
        }
        .padding(.vertical, 6)
    }

    private var buttonTitle: String {
        if loggedOnDay { return "Update weight" }
        return isToday ? "Log today's weight" : "Log weight for this day"
    }

    private var detail: String {
        guard let point else { return "Log your weight now and then to see your trend." }
        var parts: [String] = []
        if !loggedOnDay {
            parts.append("Last logged \(point.date.formatted(.dateTime.day().month()))")
        }
        parts.append("Trend \(unit.format(kg: point.trendKg))")
        if let weeklyRate {
            parts.append("\(unit.formatChange(kg: weeklyRate)) a week")
        }
        if goalKg > 0 {
            let remaining = abs(point.trendKg - goalKg)
            parts.append(remaining < 0.1 ? "At your goal" : "\(unit.format(kg: remaining)) to goal")
        }
        return parts.joined(separator: " · ")
    }
}
