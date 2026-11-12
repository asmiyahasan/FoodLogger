import SwiftUI
import SwiftData

/// Create a new meal or edit an existing one. For now items are entered by hand;
/// the photo + voice flow will fill the same screen later.
struct MealEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @AppStorage(SettingsKey.keepMealPhotos) private var keepMealPhotos = true

    let meal: Meal?
    /// From photo + voice capture (new meals only).
    private let photo: Data?
    private let transcript: String

    @State private var timestamp: Date
    @State private var mealType: MealType
    @State private var items: [DraftItem]
    @State private var editingItem: DraftItem?

    init(
        meal: Meal? = nil,
        defaultDate: Date = .now,
        drafts: [DraftItem] = [],
        photo: Data? = nil,
        transcript: String = ""
    ) {
        self.meal = meal
        self.photo = meal?.photo ?? photo
        self.transcript = meal?.transcript ?? transcript
        let time = meal?.timestamp ?? defaultDate
        _timestamp = State(initialValue: time)
        _mealType = State(initialValue: meal?.mealType ?? MealType.inferred(from: time))
        _items = State(initialValue: meal.map { $0.sortedItems.map { DraftItem(item: $0) } } ?? drafts)
    }

    private var itemsToCheck: Int { items.filter(\.needsCheck).count }

    private var totals: Nutrients { items.reduce(Nutrients.zero) { $0 + $1.nutrients } }

    var body: some View {
        NavigationStack {
            Form {
                if photo != nil || !transcript.isEmpty {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            if let photo, let image = Image(imageData: photo) {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            if !transcript.isEmpty {
                                Text("“\(transcript)”")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        if itemsToCheck > 0 {
                            Text("\(itemsToCheck) item\(itemsToCheck == 1 ? "" : "s") marked Check: tap to confirm the food and amount.")
                        }
                    }
                }

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
            .navigationTitle(meal != nil ? "Edit meal" : (photo != nil || !transcript.isEmpty) ? "Review" : "Log food")
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
        if meal == nil {
            target.transcript = transcript
            target.photo = keepMealPhotos ? photo : nil
        }

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

    /// Learns from every logged item: remembers the food, its brand, your usual amount,
    /// how often you have it, and the words used for it.
    private func updateMyFoods(countUse: Bool) {
        var existing = (try? context.fetch(FetchDescriptor<UserFood>())) ?? []
        for draft in items where draft.saveToMyFoods || draft.isFromMyFoods {
            let name = draft.name.trimmingCharacters(in: .whitespaces)
            // Skip unmatched items with no values: there's nothing useful to remember yet.
            guard !name.isEmpty, draft.isFromMyFoods || draft.per100g.energyKcal > 0 else { continue }

            let match = existing.first { food in
                food.foodID == draft.foodID
                    || (!draft.foodID.isEmpty && food.basedOnFoodID == draft.foodID)
                    || food.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            let food: UserFood
            if let match {
                food = match
            } else {
                food = UserFood(
                    name: name,
                    nutrientsPer100g: draft.per100g,
                    defaultGrams: draft.grams,
                    basedOnFoodID: draft.isFromMyFoods ? "" : draft.foodID
                )
                context.insert(food)
                existing.append(food)
            }

            if countUse || match == nil { food.timesUsed += 1 }
            food.lastUsed = .now
            food.defaultGrams = draft.grams
            if !draft.isFromMyFoods { food.nutrientsPer100g = draft.per100g }
            if !draft.brand.isEmpty { food.brand = draft.brand }

            // Other names for it ("chilli jam" for your Beerenberg jar) so it matches next time.
            for alias in [name, draft.matchedName] where !alias.isEmpty {
                let isNew = alias.localizedCaseInsensitiveCompare(food.name) != .orderedSame
                    && !food.aliases.contains { $0.localizedCaseInsensitiveCompare(alias) == .orderedSame }
                if isNew { food.aliases.append(alias) }
            }
        }
    }
}

struct DraftItemRow: View {
    let item: DraftItem
    let unit: EnergyUnit

    private var detail: String {
        var parts = [gramsText(item.grams), item.sourceLabel]
        if item.origin != .user { parts.append(item.origin.label) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name.isEmpty ? "Unnamed item" : item.name)
                    if item.needsCheck {
                        TagLabel(text: "Check")
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(Theme.deepOrangeText)
                }
            }
            Spacer()
            Text(unit.format(kcal: item.nutrients.energyKcal))
                .font(.rounded(.subheadline))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    MealEditorView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
