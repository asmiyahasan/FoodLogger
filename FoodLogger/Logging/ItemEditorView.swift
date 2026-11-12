import SwiftUI
import SwiftData

/// Add or edit one food item. Values are entered per 100 g, matching the
/// "per 100 g" column on Australian nutrition labels.
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @Query(sort: \UserFood.lastUsed, order: .reverse) private var myFoods: [UserFood]

    @State private var draft: DraftItem
    let onSave: (DraftItem) -> Void

    init(item: DraftItem, onSave: @escaping (DraftItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && draft.grams > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                if !myFoods.isEmpty {
                    Section {
                        Menu {
                            ForEach(myFoods) { food in
                                Button(food.name) { apply(food) }
                            }
                        } label: {
                            Label("Choose from my foods", systemImage: "star")
                        }
                    }
                }

                Section("Food") {
                    TextField("Name", text: $draft.name)
                    NumberField(title: "Amount", value: $draft.grams, unit: "g")
                }

                Section {
                    NumberField(title: "Energy", value: energyPer100g, unit: energyUnit.symbol)
                    NumberField(title: "Protein", value: $draft.per100g.protein, unit: "g")
                    NumberField(title: "Fat", value: $draft.per100g.fat, unit: "g")
                    NumberField(title: "Saturated fat", value: $draft.per100g.saturatedFat, unit: "g")
                    NumberField(title: "Carbs", value: $draft.per100g.carbs, unit: "g")
                    NumberField(title: "Sugars", value: $draft.per100g.sugars, unit: "g")
                    NumberField(title: "Fibre", value: $draft.per100g.fibre, unit: "g")
                    NumberField(title: "Sodium", value: $draft.per100g.sodiumMg, unit: "mg")
                } header: {
                    Text("Per 100 g")
                } footer: {
                    Text("This amount: \(energyUnit.format(kcal: draft.nutrients.energyKcal)), \(gramsText(draft.nutrients.protein)) protein")
                }

                if !draft.isFromMyFoods {
                    Section {
                        Toggle("Save to my foods", isOn: $draft.saveToMyFoods)
                    } footer: {
                        Text("Saved foods can be picked next time instead of typing the values again.")
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "Add item" : draft.name)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    /// Energy shown and typed in the user's unit, stored in kcal.
    private var energyPer100g: Binding<Double> {
        Binding(
            get: { energyUnit.value(fromKcal: draft.per100g.energyKcal) },
            set: { draft.per100g.energyKcal = energyUnit.kcal(from: $0) }
        )
    }

    private func apply(_ food: UserFood) {
        draft.name = food.name
        draft.per100g = food.nutrientsPer100g
        draft.grams = food.defaultGrams
        draft.foodID = food.foodID
        draft.sourceLabel = "My foods"
        draft.origin = .user
        draft.saveToMyFoods = false
    }
}
