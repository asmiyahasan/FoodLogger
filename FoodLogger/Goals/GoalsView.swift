import SwiftUI
import SwiftData

/// All daily goals in one place: energy, macros, fibre and water.
struct GoalsView: View {
    @Environment(\.modelContext) private var context
    /// A short line shown at the top (used during first-time setup).
    var intro: String? = nil
    var showsReset = true

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
    @AppStorage(SettingsKey.waterRemindersOn) private var remindersOn = false
    @AppStorage(SettingsKey.waterReminderStartHour) private var reminderStart = GoalDefaults.reminderStartHour
    @AppStorage(SettingsKey.waterReminderEndHour) private var reminderEnd = GoalDefaults.reminderEndHour
    @AppStorage(SettingsKey.waterReminderIntervalHours) private var reminderInterval = GoalDefaults.reminderIntervalHours
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kg
    @AppStorage(SettingsKey.goalWeightKg) private var goalWeightKg = 0.0
    @AppStorage(SettingsKey.showWeightOnToday) private var showWeightOnToday = true
    @Query(sort: \WeightEntry.timestamp, order: .reverse) private var weights: [WeightEntry]
    @State private var notificationsBlocked = false

    @State private var confirmingReset = false

    var body: some View {
        Form {
            if let intro {
                Section {
                    Text(intro)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                NumberField(title: "Daily energy", value: energyGoal, unit: energyUnit.symbol)
            } header: {
                Text("Energy")
            } footer: {
                Text("Your macros and fibre can follow this number automatically.")
            }

            Section {
                Toggle("Set from calories", isOn: $macrosFromCalories)
                if macrosFromCalories {
                    Picker("Split", selection: $macroPreset) {
                        ForEach(MacroPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    if macroPreset == .custom {
                        Stepper("Protein \(Int(customProteinPercent))%", value: $customProteinPercent, in: 10...50, step: 5)
                        Stepper("Fat \(Int(customFatPercent))%", value: $customFatPercent, in: 15...50, step: 5)
                    }
                    macroRow("Protein", grams: macroGoals.protein, percent: proteinPercent)
                    macroRow("Carbs", grams: macroGoals.carbs, percent: max(100 - proteinPercent - fatPercent, 0))
                    macroRow("Fat", grams: macroGoals.fat, percent: fatPercent)
                } else {
                    NumberField(title: "Protein", value: $goalProtein, unit: "g")
                    NumberField(title: "Carbs", value: $goalCarbs, unit: "g")
                    NumberField(title: "Fat", value: $goalFat, unit: "g")
                }
            } header: {
                Text("Macros")
            } footer: {
                if macrosFromCalories {
                    Text("Protein and carbs have 4 kcal per gram, fat 9. Change your energy goal and these update.")
                } else {
                    Text("You're setting exact grams yourself.")
                }
            }

            Section {
                Toggle("Set from calories", isOn: $fibreFromCalories)
                if fibreFromCalories {
                    LabeledContent("Fibre") {
                        Text(gramsText(fibreGoal.rounded())).monospacedDigit()
                    }
                } else {
                    NumberField(title: "Fibre", value: $goalFibre, unit: "g")
                }
            } header: {
                Text("Fibre")
            } footer: {
                Text(fibreFromCalories
                     ? "14 g per 1,000 kcal (US dietary guidelines)."
                     : "Australian guidance: about 25 g a day for women, 30 g for men.")
            }

            Section {
                NumberField(title: "Daily water", value: $goalWater, unit: "ml")
                NumberField(title: "First button", value: $quickWater1, unit: "ml")
                NumberField(title: "Second button", value: $quickWater2, unit: "ml")
            } header: {
                Text("Water")
            } footer: {
                Text("Set the buttons to the glasses or bottles you usually drink from.")
            }

            Section {
                Toggle("Water reminders", isOn: $remindersOn)
                if remindersOn {
                    Picker("From", selection: $reminderStart) {
                        ForEach(5...12, id: \.self) { hour in Text(Self.hourLabel(hour)).tag(hour) }
                    }
                    Picker("Until", selection: $reminderEnd) {
                        ForEach(15...23, id: \.self) { hour in Text(Self.hourLabel(hour)).tag(hour) }
                    }
                    Picker("Every", selection: $reminderInterval) {
                        Text("1 hour").tag(1.0)
                        Text("1½ hours").tag(1.5)
                        Text("2 hours").tag(2.0)
                        Text("3 hours").tag(3.0)
                    }
                }
            } footer: {
                if notificationsBlocked {
                    Text("Notifications are off for FoodLogger. Turn them on in Settings → Notifications → FoodLogger.")
                        .foregroundStyle(Theme.deepOrangeText)
                } else {
                    Text("Only sent when you're behind pace for the day, and they stop once you reach your goal. Log water right from the notification.")
                }
            }

            Section {
                Toggle("Goal weight", isOn: hasGoalWeight)
                if goalWeightKg > 0 {
                    NumberField(title: "Target", value: goalWeightInUnit, unit: weightUnit.symbol)
                }
                Toggle("Show weight on Today", isOn: $showWeightOnToday)
            } header: {
                Text("Weight")
            } footer: {
                Text("Progress is measured from your smoothed trend, not a single weigh-in, so day-to-day ups and downs don't throw it off.")
            }

            if showsReset {
                Section {
                    Button("Reset all goals", role: .destructive) {
                        confirmingReset = true
                    }
                } footer: {
                    Text("Goes back to the starting goals. Your logged meals and water aren't affected.")
                }
            }
        }
        .onChange(of: remindersOn) { _, isOn in
            Task {
                if isOn, !(await WaterReminders.requestPermission()) {
                    remindersOn = false
                    notificationsBlocked = true
                    return
                }
                notificationsBlocked = false
                await WaterReminders.reschedule(context: context)
            }
        }
        .onChange(of: reminderStart) { refreshReminders() }
        .onChange(of: reminderEnd) { refreshReminders() }
        .onChange(of: reminderInterval) { refreshReminders() }
        .onChange(of: goalWater) { refreshReminders() }
        .onChange(of: quickWater1) { refreshReminders() }
        .onChange(of: quickWater2) { refreshReminders() }
        .navigationTitle("Goals")
        .inlineNavigationTitle()
        .confirmationDialog("Reset all goals?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset all goals", role: .destructive) { resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Energy, macros, fibre, water and weight goals go back to their starting values.")
        }
    }

    // MARK: - Helpers

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

    private var fibreGoal: Double {
        FibreGoal.effective(fromCalories: fibreFromCalories, energyKcal: goalEnergy, manual: goalFibre)
    }

    private var proteinPercent: Double { macroPreset.split?.protein ?? customProteinPercent }
    private var fatPercent: Double { macroPreset.split?.fat ?? customFatPercent }

    private func macroRow(_ name: String, grams: Double, percent: Double) -> some View {
        LabeledContent(name) {
            Text("\(gramsText(grams.rounded()))  ·  \(Int(percent))%")
                .monospacedDigit()
        }
    }

    /// The energy goal shown in the chosen unit, stored in kcal.
    private var energyGoal: Binding<Double> {
        Binding(
            get: { energyUnit.value(fromKcal: goalEnergy) },
            set: { goalEnergy = energyUnit.kcal(from: $0) }
        )
    }

    /// Turning the goal on starts from your latest weight (or 70 kg).
    private var hasGoalWeight: Binding<Bool> {
        Binding(
            get: { goalWeightKg > 0 },
            set: { isOn in goalWeightKg = isOn ? (weights.first?.kilograms ?? 70).rounded() : 0 }
        )
    }

    /// The goal shown in the chosen unit, stored in kilograms.
    private var goalWeightInUnit: Binding<Double> {
        Binding(
            get: { weightUnit.value(fromKg: goalWeightKg) },
            set: { goalWeightKg = max(weightUnit.kg(from: $0), 0) }
        )
    }

    private func refreshReminders() {
        Task { await WaterReminders.reschedule(context: context) }
    }

    static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func resetAll() {
        goalEnergy = GoalDefaults.energyKcal
        goalProtein = GoalDefaults.protein
        goalCarbs = GoalDefaults.carbs
        goalFat = GoalDefaults.fat
        goalFibre = GoalDefaults.fibre
        goalWater = GoalDefaults.waterMl
        quickWater1 = GoalDefaults.quickWater1
        quickWater2 = GoalDefaults.quickWater2
        macrosFromCalories = true
        macroPreset = .balanced
        customProteinPercent = GoalDefaults.customProteinPercent
        customFatPercent = GoalDefaults.customFatPercent
        fibreFromCalories = false
        goalWeightKg = 0
        showWeightOnToday = true
    }
}

#Preview {
    NavigationStack { GoalsView() }
}
