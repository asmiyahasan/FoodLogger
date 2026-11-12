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
                    NumberField(title: "Protein", value: $goalProtein, unit: "g")
                    NumberField(title: "Carbs", value: $goalCarbs, unit: "g")
                    NumberField(title: "Fat", value: $goalFat, unit: "g")
                    NumberField(title: "Fibre", value: $goalFibre, unit: "g")
                    NumberField(title: "Water", value: $goalWater, unit: "ml")
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

                Section("My foods") {
                    NavigationLink {
                        MyFoodsView()
                    } label: {
                        LabeledContent("Saved foods", value: "\(myFoods.count)")
                    }
                }
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
