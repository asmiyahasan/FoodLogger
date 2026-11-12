import SwiftUI
import SwiftData

/// The home screen: one day's totals, water and meals, with a Log food button.
struct TodayView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var showingNewMeal = false
    @State private var showingCapture = false
    @State private var showingSettings = false
    @State private var showingGoals = false
    @State private var showingHistory = false
    @State private var editingMeal: Meal?

    var body: some View {
        NavigationStack {
            DayView(day: $day, editingMeal: $editingMeal, showingGoals: $showingGoals)
                .id(day)
                .navigationTitle("FoodLogger")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("History", systemImage: "calendar") {
                            showingHistory = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Goals", systemImage: "target") {
                            showingGoals = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Settings", systemImage: "gearshape") {
                            showingSettings = true
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 12) {
                        Button {
                            showingCapture = true
                        } label: {
                            Label("Snap a meal", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)

                        Button {
                            showingNewMeal = true
                        } label: {
                            Label("Type it in", systemImage: "square.and.pencil")
                                .labelStyle(.iconOnly)
                                .font(.headline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Log food by typing")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
        }
        .sheet(isPresented: $showingCapture) {
            CaptureView(defaultDate: DayView.entryTimestamp(for: day))
        }
        .sheet(isPresented: $showingNewMeal) {
            MealEditorView(defaultDate: DayView.entryTimestamp(for: day))
        }
        .sheet(item: $editingMeal) { meal in
            MealEditorView(meal: meal)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView { picked in
                day = Calendar.current.startOfDay(for: picked)
            }
        }
        .sheet(isPresented: $showingGoals) {
            NavigationStack {
                GoalsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingGoals = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

/// Everything shown for one day. Its queries are rebuilt whenever the day changes.
struct DayView: View {
    @Binding var day: Date
    @Binding var editingMeal: Meal?
    @Binding var showingGoals: Bool

    @Environment(\.modelContext) private var context
    @Query private var meals: [Meal]
    @Query private var water: [WaterEntry]

    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @AppStorage(SettingsKey.goalEnergyKcal) private var goalEnergy = GoalDefaults.energyKcal
    @AppStorage(SettingsKey.goalProtein) private var goalProtein = GoalDefaults.protein
    @AppStorage(SettingsKey.goalCarbs) private var goalCarbs = GoalDefaults.carbs
    @AppStorage(SettingsKey.goalFat) private var goalFat = GoalDefaults.fat
    @AppStorage(SettingsKey.goalFibre) private var goalFibre = GoalDefaults.fibre
    @AppStorage(SettingsKey.goalWaterMl) private var goalWater = GoalDefaults.waterMl
    @AppStorage(SettingsKey.quickWater1) private var quickWater1 = GoalDefaults.quickWater1
    @AppStorage(SettingsKey.quickWater2) private var quickWater2 = GoalDefaults.quickWater2
    @AppStorage(SettingsKey.macrosFromCalories) private var macrosFromCalories = true
    @AppStorage(SettingsKey.macroPreset) private var macroPreset: MacroPreset = .balanced
    @AppStorage(SettingsKey.customProteinPercent) private var customProteinPercent = GoalDefaults.customProteinPercent
    @AppStorage(SettingsKey.customFatPercent) private var customFatPercent = GoalDefaults.customFatPercent
    @AppStorage(SettingsKey.fibreFromCalories) private var fibreFromCalories = false

    init(day: Binding<Date>, editingMeal: Binding<Meal?>, showingGoals: Binding<Bool>) {
        _day = day
        _editingMeal = editingMeal
        _showingGoals = showingGoals
        let start = Calendar.current.startOfDay(for: day.wrappedValue)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        _meals = Query(
            filter: #Predicate<Meal> { meal in meal.timestamp >= start && meal.timestamp < end },
            sort: \Meal.timestamp
        )
        _water = Query(
            filter: #Predicate<WaterEntry> { entry in entry.timestamp >= start && entry.timestamp < end },
            sort: \WaterEntry.timestamp
        )
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var macroGoals: MacroGoals {
        MacroGoals.effective(
            fromCalories: macrosFromCalories,
            energyKcal: goalEnergy,
            preset: macroPreset,
            customProteinPercent: customProteinPercent,
            customFatPercent: customFatPercent,
            manual: MacroGoals(protein: goalProtein, carbs: goalCarbs, fat: goalFat)
        )
    }

    private var loggedMeals: [Meal] { meals.filter { $0.status == .logged } }
    private var totals: Nutrients { loggedMeals.reduce(Nutrients.zero) { $0 + $1.totals } }
    private var waterTotal: Double { water.reduce(0) { $0 + $1.millilitres } }

    var body: some View {
        List {
            Section {
                dayPicker
                HStack(spacing: 20) {
                    EnergyRing(consumedKcal: totals.energyKcal, goalKcal: goalEnergy, unit: energyUnit)
                        .frame(width: 120, height: 120)
                    VStack(spacing: 10) {
                        GoalBar(label: "Protein", value: totals.protein, goal: macroGoals.protein, unit: "g")
                        GoalBar(label: "Carbs", value: totals.carbs, goal: macroGoals.carbs, unit: "g")
                        GoalBar(label: "Fat", value: totals.fat, goal: macroGoals.fat, unit: "g")
                        GoalBar(label: "Fibre", value: totals.fibre, goal: FibreGoal.effective(fromCalories: fibreFromCalories, energyKcal: goalEnergy, manual: goalFibre), unit: "g")
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { showingGoals = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens your goals")
            }

            Section {
                WaterCard(
                    totalMl: waterTotal,
                    goalMl: goalWater,
                    quickSizes: [quickWater1, quickWater2],
                    canUndo: !water.isEmpty,
                    add: addWater,
                    undo: undoWater
                )
                .listRowBackground(Theme.tint)
            }

            Section("Meals") {
                if meals.isEmpty {
                    Text("Nothing logged yet. Tap Snap a meal to add one.")
                        .foregroundStyle(.secondary)
                }
                ForEach(meals) { meal in
                    Button {
                        editingMeal = meal
                    } label: {
                        MealRow(meal: meal, unit: energyUnit)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(meal)
                        }
                    }
                    .contextMenu {
                        Button("Log again", systemImage: "arrow.counterclockwise") {
                            logAgain(meal)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(meal)
                        }
                    }
                }
            }
        }
    }

    private var dayPicker: some View {
        HStack {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous day")

            Spacer()
            VStack(spacing: 2) {
                Text(isToday ? "Today" : day.formatted(.dateTime.weekday(.wide)))
                    .font(.rounded(.title3, weight: .bold))
                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isToday)
            .accessibilityLabel("Next day")
        }
        .buttonStyle(.borderless)
        .font(.headline)
        .tint(Theme.turquoise)
    }

    private func shiftDay(by days: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: days, to: day) {
            day = Calendar.current.startOfDay(for: newDay)
        }
    }

    /// "Now" when viewing today; midday when adding to a past day.
    static func entryTimestamp(for day: Date) -> Date {
        if Calendar.current.isDateInToday(day) { return .now }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private func addWater(_ millilitres: Double) {
        context.insert(WaterEntry(millilitres: millilitres, timestamp: Self.entryTimestamp(for: day)))
    }

    private func undoWater() {
        if let last = water.last {
            context.delete(last)
        }
    }

    private func logAgain(_ meal: Meal) {
        let copy = Meal(timestamp: Self.entryTimestamp(for: day))
        copy.photo = meal.photo
        context.insert(copy)
        for item in meal.sortedItems {
            let newItem = MealItem(
                name: item.name,
                grams: item.grams,
                nutrientsPer100g: item.nutrientsPer100g,
                foodID: item.foodID,
                sourceLabel: item.sourceLabel,
                origin: item.origin,
                confidence: item.confidence,
                position: item.position
            )
            context.insert(newItem)
            newItem.meal = copy
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
