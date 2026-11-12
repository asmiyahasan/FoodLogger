import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var myFoods: [UserFood]

    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @AppStorage(SettingsKey.goalEnergyKcal) private var goalEnergy = GoalDefaults.energyKcal
    @AppStorage(SettingsKey.goalProtein) private var goalProtein = GoalDefaults.protein
    @AppStorage(SettingsKey.goalCarbs) private var goalCarbs = GoalDefaults.carbs
    @AppStorage(SettingsKey.goalFat) private var goalFat = GoalDefaults.fat
    @AppStorage(SettingsKey.goalFibre) private var goalFibre = GoalDefaults.fibre
    @AppStorage(SettingsKey.goalWaterMl) private var goalWater = GoalDefaults.waterMl
    @AppStorage(SettingsKey.quickWater1) private var quickWater1 = GoalDefaults.quickWater1
    @AppStorage(SettingsKey.quickWater2) private var quickWater2 = GoalDefaults.quickWater2
    @AppStorage(SettingsKey.keepMealPhotos) private var keepMealPhotos = true
    @AppStorage(SettingsKey.macrosFromCalories) private var macrosFromCalories = true
    @AppStorage(SettingsKey.macroPreset) private var macroPreset: MacroPreset = .balanced
    @AppStorage(SettingsKey.customProteinPercent) private var customProteinPercent = GoalDefaults.customProteinPercent
    @AppStorage(SettingsKey.customFatPercent) private var customFatPercent = GoalDefaults.customFatPercent

    @State private var usdaKeyInput = ""
    @State private var hasUSDAKey = KeychainStore.read(.usdaAPIKey) != nil
    private let usdaKeyInSecretsFile = APIKeys.fromSecretsFile(.usdaAPIKey) != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Energy", selection: $energyUnit) {
                        ForEach(EnergyUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                }

                Section("Daily goals") {
                    NumberField(title: "Energy", value: energyGoal, unit: energyUnit.symbol)
                    NumberField(title: "Fibre", value: $goalFibre, unit: "g")
                    NumberField(title: "Water", value: $goalWater, unit: "ml")
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
                        macroRow("Carbs", grams: macroGoals.carbs, percent: 100 - proteinPercent - fatPercent)
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
                        Text("Grams update when you change your calorie goal. Protein and carbs have 4 kcal per gram, fat 9.")
                    } else {
                        Text("Set exact grams yourself.")
                    }
                }

                Section {
                    NumberField(title: "First button", value: $quickWater1, unit: "ml")
                    NumberField(title: "Second button", value: $quickWater2, unit: "ml")
                } header: {
                    Text("Water buttons")
                } footer: {
                    Text("Set these to the glasses or bottles you usually drink from.")
                }

                Section {
                    Toggle("Keep meal photos", isOn: $keepMealPhotos)
                } footer: {
                    Text("When off, a meal's photo is deleted once the meal is logged.")
                }

                Section {
                    if hasUSDAKey {
                        LabeledContent("API key", value: "Saved")
                        Button("Remove key", role: .destructive) {
                            KeychainStore.delete(.usdaAPIKey)
                            hasUSDAKey = false
                        }
                    } else if usdaKeyInSecretsFile {
                        LabeledContent("API key", value: "Set in Secrets.plist")
                    } else {
                        SecureField("Paste your API key", text: $usdaKeyInput)
                        Button("Save key") {
                            let key = usdaKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            hasUSDAKey = KeychainStore.save(key, for: .usdaAPIKey)
                            usdaKeyInput = ""
                        }
                        .disabled(usdaKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("USDA FoodData Central")
                } footer: {
                    Text("Stored only in this device's Keychain. Get a free key at fdc.nal.usda.gov.")
                }

                Section("My foods") {
                    NavigationLink {
                        MyFoodsView()
                    } label: {
                        LabeledContent("Saved foods", value: "\(myFoods.count)")
                    }
                }

                Section("Data sources") {
                    Text("Australian Food Composition Database, Release 3 © Food Standards Australia New Zealand, licensed under CC BY 4.0.")
                    Text("Open Food Facts data © Open Food Facts contributors, licensed under the Open Database License.")
                    Text("USDA FoodData Central, U.S. Department of Agriculture (public domain).")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

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

    private var proteinPercent: Double {
        macroPreset.split?.protein ?? customProteinPercent
    }

    private var fatPercent: Double {
        macroPreset.split?.fat ?? customFatPercent
    }

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
}

struct MyFoodsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @Query(sort: \UserFood.name) private var foods: [UserFood]

    var body: some View {
        List {
            if foods.isEmpty {
                ContentUnavailableView(
                    "No saved foods",
                    systemImage: "star",
                    description: Text("Turn on Save to my foods when adding an item.")
                )
            }
            ForEach(foods) { food in
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                    Text("\(energyUnit.format(kcal: food.nutrientsPer100g.energyKcal)) per 100 g · usually \(gramsText(food.defaultGrams))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(foods[index])
                }
            }
        }
        .navigationTitle("My foods")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
