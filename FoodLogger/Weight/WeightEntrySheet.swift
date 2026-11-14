import SwiftData
import SwiftUI

/// Log or edit the weigh-in for one day.
struct WeightEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.weightUnit) private var unit: WeightUnit = .kg
    @Query(sort: \WeightEntry.timestamp) private var weights: [WeightEntry]

    @State private var date: Date
    @State private var kilograms: Double = 0
    @State private var didPrefill = false

    init(day: Date) {
        _date = State(initialValue: Calendar.current.startOfDay(for: day))
    }

    /// The entry already logged on the chosen day, if any.
    private var existing: WeightEntry? {
        weights.last { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    NumberField(title: "Weight", value: weightInUnit, unit: unit.symbol)
                } footer: {
                    Text("Weigh yourself at the same time each day, ideally first thing in the morning, for the steadiest trend.")
                }

                if let existing {
                    Section {
                        Button("Delete this weigh-in", role: .destructive) {
                            context.delete(existing)
                            try? context.save()
                            rescheduleReminders()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Log weight" : "Edit weight")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(kilograms <= 0)
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: date) { prefill() }
        }
        .presentationDetents([.medium, .large])
    }

    /// The weight shown in the chosen unit, stored in kilograms.
    private var weightInUnit: Binding<Double> {
        Binding(
            get: { unit.value(fromKg: kilograms) },
            set: { kilograms = unit.kg(from: $0) }
        )
    }

    /// Start from that day's entry, or from your most recent weight.
    private func prefill() {
        if let existing {
            kilograms = existing.kilograms
        } else if !didPrefill, let latest = weights.last {
            kilograms = latest.kilograms
        }
        didPrefill = true
    }

    private func save() {
        if let existing {
            existing.kilograms = kilograms
        } else {
            context.insert(WeightEntry(kilograms: kilograms, timestamp: DayView.entryTimestamp(for: date)))
        }
        try? context.save()
        rescheduleReminders()
        dismiss()
    }

    /// The next weigh-in reminder counts from your latest weigh-in.
    private func rescheduleReminders() {
        let context = self.context
        Task { await WeightReminders.reschedule(context: context) }
    }
}
