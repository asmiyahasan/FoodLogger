import SwiftUI
import SwiftData

/// The home screen: one day's totals, water and meals, with a Log food button.
struct TodayView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var showingNewMeal = false
    @State private var showingCapture = false
    @State private var showingBarcode = false
    @AppStorage(SettingsKey.pendingLaunchAction) private var pendingLaunchAction = ""
    @State private var showingSettings = false
    @State private var showingGoals = false
    @State private var showingHistory = false
    @State private var editingMeal: Meal?

    var body: some View {
        NavigationStack {
            DayView(day: $day, editingMeal: $editingMeal, showingGoals: $showingGoals)
                .id(day)
                .navigationTitle("")
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

                        #if os(iOS)
                        Button {
                            showingBarcode = true
                        } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                                .labelStyle(.iconOnly)
                                .font(.headline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Scan a barcode")
                        #endif

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
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(.bar)   // keeps the meal list from showing through the buttons
                }
        }
        .onAppear(perform: handleLaunchAction)
        .onChange(of: pendingLaunchAction) { handleLaunchAction() }
        .sheet(isPresented: $showingBarcode) {
            BarcodeLogView(defaultDate: DayView.entryTimestamp(for: day))
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

extension TodayView {
    /// Opens the camera when the app was launched by "Snap a meal" (Siri or Shortcuts).
    func handleLaunchAction() {
        guard pendingLaunchAction == "capture" else { return }
        pendingLaunchAction = ""
        day = Calendar.current.startOfDay(for: .now)
        showingCapture = true
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
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    @AppStorage(SettingsKey.showWeightOnToday) private var showWeight = true
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kg
    @AppStorage(SettingsKey.goalWeightKg) private var goalWeightKg = 0.0
    @State private var showingWeightEntry = false

    @AppStorage(SettingsKey.userName) private var userName = ""
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
                HStack(spacing: 14) {
                    AppLogo(size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting(for: userName))
                            .font(.rounded(.largeTitle, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(Self.dayMessage(for: .now))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            if AppExpiry.isExpiringSoon, let expiry = AppExpiry.expiryDate {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh needed \(expiry.formatted(.relative(presentation: .named)))")
                                .font(.subheadline.weight(.semibold))
                            Text("Open Xcode and press Run to keep FoodLogger working.\(BackupService.backupIsDue ? " Back up your data in Settings too." : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(Theme.deepOrange)
                    }
                }
            }

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

            if showWeight {
                Section {
                    weightCard
                }
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
        .sheet(isPresented: $showingWeightEntry) {
            WeightEntrySheet(day: day)
        }
    }

    private var weightCard: some View {
        // Only the weigh-ins up to the day being viewed count.
        let points = WeightTrend.points(from: weights.map(\.reading))
            .filter { $0.date <= Calendar.current.startOfDay(for: day) }
        let point = points.last
        return WeightCard(
            point: point,
            loggedOnDay: point.map { Calendar.current.isDate($0.date, inSameDayAs: day) } ?? false,
            weeklyRate: WeightTrend.weeklyRate(points),
            goalKg: goalWeightKg,
            unit: weightUnit,
            isToday: isToday,
            log: { showingWeightEntry = true }
        )
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

    /// A short line under the greeting, by time of day.
    static func dayMessage(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning. What's for breakfast?"
        case 12..<17: "Good afternoon. Keep it going."
        case 17..<22: "Good evening. How was today?"
        default: "Late one? Don't forget to log it."
        }
    }

    /// "Now" when viewing today; midday when adding to a past day.
    static func entryTimestamp(for day: Date) -> Date {
        if Calendar.current.isDateInToday(day) { return .now }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private func addWater(_ millilitres: Double) {
        context.insert(WaterEntry(millilitres: millilitres, timestamp: Self.entryTimestamp(for: day)))
        refreshReminders()
    }

    private func undoWater() {
        if let last = water.last {
            context.delete(last)
            refreshReminders()
        }
    }

    private func refreshReminders() {
        try? context.save()
        Task { await WaterReminders.reschedule(context: context) }
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
                position: item.position,
                dish: item.dish,
                unitName: item.unitName,
                measures: item.measures
            )
            context.insert(newItem)
            newItem.meal = copy
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self, WeightEntry.self], inMemory: true)
}
