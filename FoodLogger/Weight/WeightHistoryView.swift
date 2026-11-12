import Charts
import SwiftData
import SwiftUI

/// Weight chart with the smoothed trend, progress towards the goal, and every weigh-in.
struct WeightHistoryView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.weightUnit) private var unit: WeightUnit = .kg
    @AppStorage(SettingsKey.goalWeightKg) private var goalKg = 0.0
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    @State private var range: ChartRange = .threeMonths
    @State private var editingDay: EditDay?

    enum ChartRange: String, CaseIterable, Identifiable {
        case month = "1M", threeMonths = "3M", year = "1Y", all = "All"
        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .month: 30
            case .threeMonths: 91
            case .year: 365
            case .all: nil
            }
        }
    }

    struct EditDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    var body: some View {
        let points = WeightTrend.points(from: weights.map(\.reading))
        let shown = visible(points)
        List {
            if points.isEmpty {
                Section {
                    Text("No weigh-ins yet. Tap + to log your first one.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chart(shown)
                    legend
                }
                Section {
                    stats(all: points, shown: shown)
                }
                Section("Weigh-ins") {
                    ForEach(points.reversed()) { point in
                        Button {
                            editingDay = EditDay(date: point.date)
                        } label: {
                            LabeledContent {
                                Text(unit.format(kg: point.kg)).monospacedDigit()
                            } label: {
                                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(day: point.date)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Weight")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Log weight", systemImage: "plus") {
                    editingDay = EditDay(date: .now)
                }
            }
        }
        .sheet(item: $editingDay) { day in
            WeightEntrySheet(day: day.date)
        }
    }

    // MARK: - Chart

    private func visible(_ points: [WeightPoint]) -> [WeightPoint] {
        guard let days = range.days else { return points }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        return points.filter { $0.date >= start }
    }

    private func chart(_ points: [WeightPoint]) -> some View {
        let values = points.flatMap { [unit.value(fromKg: $0.kg), unit.value(fromKg: $0.trendKg)] }
        let goal = goalKg > 0 ? unit.value(fromKg: goalKg) : nil
        // Include the goal only if it's reasonably close, so it doesn't squash the line flat.
        var low = values.min() ?? 0
        var high = values.max() ?? 1
        if let goal, goal > low - 10, goal < high + 10 {
            low = min(low, goal)
            high = max(high, goal)
        }
        let padding = max((high - low) * 0.15, 0.5)

        return Chart {
            ForEach(points) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Weight", unit.value(fromKg: point.kg))
                )
                .symbolSize(20)
                .foregroundStyle(Theme.orange.opacity(0.6))
            }
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Trend", unit.value(fromKg: point.trendKg)),
                    series: .value("Series", "Trend")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(Theme.turquoise)
            }
            if let goal, goal >= low, goal <= high {
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: (low - padding)...(high + padding))
        .chartYAxisLabel(unit.symbol)
        .frame(height: 220)
        .padding(.vertical, 6)
        .accessibilityLabel("Weight and trend over time")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label {
                Text("Weigh-ins")
            } icon: {
                Circle().fill(Theme.orange.opacity(0.6)).frame(width: 8, height: 8)
            }
            Label {
                Text("Trend")
            } icon: {
                Capsule().fill(Theme.turquoise).frame(width: 16, height: 3)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Stats

    private func stats(all points: [WeightPoint], shown: [WeightPoint]) -> some View {
        let latest = points.last
        let change: Double? = {
            guard let first = shown.first, let last = shown.last, first.date != last.date else { return nil }
            return last.trendKg - first.trendKg
        }()
        let rate = WeightTrend.weeklyRate(points)

        return Group {
            if let latest {
                LabeledContent("Trend now", value: unit.format(kg: latest.trendKg))
            }
            if let change {
                LabeledContent("Change (\(range.rawValue))", value: unit.formatChange(kg: change))
            }
            LabeledContent("Per week", value: rate.map { unit.formatChange(kg: $0) } ?? "Needs a week of weigh-ins")
            if goalKg > 0, let latest {
                let remaining = latest.trendKg - goalKg
                LabeledContent("Goal", value: unit.format(kg: goalKg))
                LabeledContent("To go", value: abs(remaining) < 0.1 ? "You're there" : unit.format(kg: abs(remaining)))
            }
        }
        .monospacedDigit()
    }

    private func delete(day: Date) {
        for entry in weights where Calendar.current.isDate(entry.timestamp, inSameDayAs: day) {
            context.delete(entry)
        }
        try? context.save()
    }
}

#Preview {
    NavigationStack { WeightHistoryView() }
        .modelContainer(for: [WeightEntry.self], inMemory: true)
}
