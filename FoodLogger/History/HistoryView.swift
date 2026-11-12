import SwiftUI
import SwiftData
import Charts

/// Month calendar, a selected day's summary, and that week's chart and averages.
struct HistoryView: View {
    let onOpenDay: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var month = HistoryCalendar.monthStart(.now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            MonthHistory(month: $month, selectedDay: $selectedDay) { day in
                onOpenDay(day)
                dismiss()
            }
            .id(month)
            .navigationTitle("History")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Totals for one day.
struct DaySummary {
    var energyKcal: Double = 0
    var protein: Double = 0
    var mealCount = 0
    var waterMl: Double = 0
}

/// One month's calendar and the selected week. Its queries cover exactly the weeks shown.
struct MonthHistory: View {
    @Binding var month: Date
    @Binding var selectedDay: Date
    let onOpenDay: (Date) -> Void

    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @AppStorage(SettingsKey.goalEnergyKcal) private var goalEnergy = GoalDefaults.energyKcal

    private let gridDays: [Date]
    private let calendar = Calendar.current

    init(month: Binding<Date>, selectedDay: Binding<Date>, onOpenDay: @escaping (Date) -> Void) {
        _month = month
        _selectedDay = selectedDay
        self.onOpenDay = onOpenDay
        let days = HistoryCalendar.gridDays(for: month.wrappedValue)
        gridDays = days
        let start = days.first ?? month.wrappedValue
        let end = Calendar.current.date(byAdding: .day, value: 1, to: days.last ?? start) ?? start
        _meals = Query(
            filter: #Predicate<Meal> { meal in meal.timestamp >= start && meal.timestamp < end },
            sort: \Meal.timestamp
        )
        _water = Query(
            filter: #Predicate<WaterEntry> { entry in entry.timestamp >= start && entry.timestamp < end },
            sort: \WaterEntry.timestamp
        )
    }

    private var summaries: [Date: DaySummary] {
        var result: [Date: DaySummary] = [:]
        for meal in meals where meal.status == .logged {
            let day = calendar.startOfDay(for: meal.timestamp)
            let totals = meal.totals
            result[day, default: DaySummary()].energyKcal += totals.energyKcal
            result[day, default: DaySummary()].protein += totals.protein
            result[day, default: DaySummary()].mealCount += 1
        }
        for entry in water {
            result[calendar.startOfDay(for: entry.timestamp), default: DaySummary()].waterMl += entry.millilitres
        }
        return result
    }

    var body: some View {
        let summaries = self.summaries
        List {
            Section {
                monthHeader
                calendarGrid(summaries)
            }
            Section(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                dayCard(summaries[selectedDay] ?? DaySummary())
            }
            Section("Week of \(weekDays.first?.formatted(.dateTime.day().month()) ?? "")") {
                weekChart(summaries)
                weekAverages(summaries)
            }
        }
    }

    // MARK: - Calendar

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
    }

    private func calendarGrid(_ summaries: [Date: DaySummary]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(HistoryCalendar.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(gridDays, id: \.self) { day in
                dayCell(day, logged: (summaries[day]?.mealCount ?? 0) > 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(_ day: Date, logged: Bool) -> some View {
        let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date.now
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (inMonth && !isFuture ? Color.primary : Color.secondary))
                Circle()
                    .fill(logged ? (isSelected ? Color.white : Color.accentColor) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10).fill(Color.accentColor)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (logged ? ", logged" : ""))
    }

    // MARK: - Selected day

    private func dayCard(_ summary: DaySummary) -> some View {
        Group {
            if summary.mealCount == 0 && summary.waterMl == 0 {
                Text("Nothing logged this day.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent("Energy", value: "\(energyUnit.format(kcal: summary.energyKcal)) of \(energyUnit.format(kcal: goalEnergy))")
                LabeledContent("Protein", value: gramsText(summary.protein.rounded()))
                LabeledContent("Water", value: "\(litresText(summary.waterMl)) L")
                LabeledContent("Meals", value: "\(summary.mealCount)")
            }
            Button("Open this day", systemImage: "arrow.right.circle") {
                onOpenDay(selectedDay)
            }
        }
    }

    // MARK: - Week

    private var weekDays: [Date] {
        HistoryCalendar.weekDays(containing: selectedDay)
    }

    private func weekChart(_ summaries: [Date: DaySummary]) -> some View {
        Chart {
            ForEach(weekDays, id: \.self) { day in
                BarMark(
                    x: .value("Day", day, unit: .day),
                    y: .value("Energy", energyUnit.value(fromKcal: summaries[day]?.energyKcal ?? 0))
                )
                .foregroundStyle(calendar.isDate(day, inSameDayAs: selectedDay) ? Color.accentColor : Color.accentColor.opacity(0.45))
                .cornerRadius(4)
            }
            RuleMark(y: .value("Goal", energyUnit.value(fromKcal: goalEnergy)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .top, alignment: .leading) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxisLabel(energyUnit.symbol)
        .frame(height: 170)
        .padding(.vertical, 6)
        .accessibilityLabel("Energy per day this week")
    }

    private func weekAverages(_ summaries: [Date: DaySummary]) -> some View {
        let week = weekDays.compactMap { summaries[$0] }
        let loggedDays = week.filter { $0.mealCount > 0 }
        let waterDays = week.filter { $0.waterMl > 0 }
        let avgEnergy = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.energyKcal } / Double(loggedDays.count)
        let avgProtein = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.protein } / Double(loggedDays.count)
        let avgWater = waterDays.isEmpty ? 0 : waterDays.reduce(0) { $0 + $1.waterMl } / Double(waterDays.count)

        return HStack {
            stat(energyUnit.format(kcal: avgEnergy), "avg per day")
            stat(gramsText(avgProtein.rounded()), "avg protein")
            stat("\(litresText(avgWater)) L", "avg water")
        }
        .padding(.vertical, 4)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navigation

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: month) else { return }
        let start = HistoryCalendar.monthStart(newMonth)
        // Select today in the current month, otherwise the 1st.
        selectedDay = calendar.isDate(start, equalTo: .now, toGranularity: .month)
            ? calendar.startOfDay(for: .now)
            : start
        month = start
    }
}

/// Calendar maths for the history grid (weeks start on the device's first weekday, Monday in Australia).
enum HistoryCalendar {
    static func monthStart(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Every day shown in the month grid, padded to whole weeks.
    static func gridDays(for month: Date) -> [Date] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: interval.start) ?? interval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        let total = Int((Double(leading + daysInMonth) / 7).rounded(.up)) * 7
        return (0..<total).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    static func weekdaySymbols() -> [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    static func weekDays(containing day: Date) -> [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: day) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }
}

#Preview {
    HistoryView { _ in }
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
