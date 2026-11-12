import SwiftUI
import SwiftData

/// Add or edit one food item. Values are entered per 100 g, matching the
/// "per 100 g" column on Australian nutrition labels.
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @State private var draft: DraftItem
    @State private var showingSearch = false
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
                Section {
                    Button("Search foods", systemImage: "magnifyingglass") {
                        showingSearch = true
                    }
                } footer: {
                    if !draft.foodID.isEmpty {
                        Text(draft.matchedName.isEmpty
                             ? "Values from \(draft.sourceLabel)."
                             : "Values from \(draft.sourceLabel): \(draft.matchedName).")
                    } else if !draft.note.isEmpty {
                        Text(draft.note)
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
            .sheet(isPresented: $showingSearch) {
                FoodSearchView(initialQuery: draft.name) { food in
                    apply(food)
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
                        // You've reviewed it, so it no longer needs checking.
                        var reviewed = draft
                        reviewed.confidence = 1
                        reviewed.note = ""
                        onSave(reviewed)
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

    /// Fills the item from a search result. The amount keeps what you typed,
    /// unless the source gives a typical serving.
    private func apply(_ food: FoodCandidate) {
        if draft.name.isEmpty || draft.matchedName.isEmpty {
            draft.name = food.name
        }
        draft.per100g = food.per100g
        draft.foodID = food.id
        draft.sourceLabel = food.source.shortLabel
        draft.matchedName = food.name
        if let serving = food.servingGrams, serving > 0 {
            draft.grams = serving
        }
        draft.saveToMyFoods = false
    }
}
