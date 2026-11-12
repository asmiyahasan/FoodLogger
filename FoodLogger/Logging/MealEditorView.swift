import SwiftUI
import SwiftData

/// Create a new meal or edit an existing one. For now items are entered by hand;
/// the photo + voice flow will fill the same screen later.
struct MealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal

    let meal: Meal?

    @State private var timestamp: Date
    @State private var mealType: MealType
    @State private var items: [DraftItem]
    @State private var editingItem: DraftItem?

    init(meal: Meal? = nil, defaultDate: Date = .now) {
        self.meal = meal
        let time = meal?.timestamp ?? defaultDate
        _timestamp = State(initialValue: time)
        _mealType = State(initialValue: meal?.mealType ?? MealType.inferred(from: time))
        _items = State(initialValue: meal?.sortedItems.map { DraftItem(item: $0) } ?? [])
    }

    private var totals: Nutrients { items.reduce(Nutrients.zero) { $0 + $1.nutrients } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    DatePicker("Time", selection: $timestamp)
                }

                Section("Items") {
                    if items.isEmpty {
                        Text("No items yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            DraftItemRow(item: item, unit: energyUnit)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }
                    Button("Add item", systemImage: "plus") {
                        editingItem = DraftItem()
                    }
                }

                if !items.isEmpty {
                    Section("Total") {
                        LabeledContent("Energy", value: energyUnit.format(kcal: totals.energyKcal))
                        LabeledContent("Protein", value: gramsText(totals.protein))
                        LabeledContent("Carbs", value: gramsText(totals.carbs))
                        LabeledContent("Fat", value: gramsText(totals.fat))
                        LabeledContent("Fibre", value: gramsText(totals.fibre))
                    }
                }
            }
            .navigationTitle(meal == nil ? "Log food" : "Edit meal")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(items.isEmpty)
                }
            }
            .sheet(item: $editingItem) { item in
                ItemEditorView(item: item) { saved in
                    if let index = items.firstIndex(where: { $0.id == saved.id }) {
                        items[index] = saved
                    } else {
                        items.append(saved)
                    }
                }
            }
        }
    }

    private func save() {
        let target: Meal
        if let meal {
            target = meal
            for old in meal.items ?? [] {
                context.delete(old)
            }
            target.items = []
        } else {
            target = Meal(timestamp: timestamp, mealType: mealType)
            context.insert(target)
        }
        target.timestamp = timestamp
        target.mealType = mealType
        target.status = .logged

        for (index, draft) in items.enumerated() {
            let item = MealItem(
                name: draft.name.trimmingCharacters(in: .whitespaces),
                grams: draft.grams,
                nutrientsPer100g: draft.per100g,
                foodID: draft.foodID,
                sourceLabel: draft.sourceLabel,
                origin: draft.origin,
                confidence: draft.confidence,
                position: index
            )
            context.insert(item)
            item.meal = target
        }

        updateMyFoods(countUse: meal == nil)
        try? context.save()
        dismiss()
    }

    /// Saves items marked "Save to my foods" and counts uses of saved foods.
    private func updateMyFoods(countUse: Bool) {
        let existing = (try? context.fetch(FetchDescriptor<UserFood>())) ?? []
        for draft in items {
            if draft.isFromMyFoods {
                if countUse, let food = existing.first(where: { $0.foodID == draft.foodID }) {
                    food.timesUsed += 1
                    food.lastUsed = .now
                }
            } else if draft.saveToMyFoods {
                let name = draft.name.trimmingCharacters(in: .whitespaces)
                if let food = existing.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                    food.nutrientsPer100g = draft.per100g
                    food.defaultGrams = draft.grams
                    food.lastUsed = .now
                } else {
                    context.insert(UserFood(
                        name: name,
                        nutrientsPer100g: draft.per100g,
                        defaultGrams: draft.grams,
                        basedOnFoodID: draft.foodID
                    ))
                }
            }
        }
    }
}

struct DraftItemRow: View {
    let item: DraftItem
    let unit: EnergyUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed item" : item.name)
                Text("\(gramsText(item.grams)) · \(item.sourceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(unit.format(kcal: item.nutrients.energyKcal))
                .font(.subheadline)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    MealEditorView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
