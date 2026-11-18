import SwiftData
import SwiftUI

/// The workout in progress, or a past one to look at and edit.
struct WorkoutEditorView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.weightUnit) private var unit: WeightUnit = .kg

    @State private var showingPicker = false
    @State private var confirmingDiscard = false
    @State private var showingRoutineSaved = false
    /// What you did last time, by exercise name.
    @State private var previous: [String: WorkoutExercise] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workout.name)
                        .font(.rounded(.title3, weight: .bold))
                    if workout.isActive {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            LabeledContent("Time", value: Self.clock(workout.duration))
                                .monospacedDigit()
                        }
                    } else {
                        DatePicker("Started", selection: $workout.startedAt)
                        LabeledContent("Duration", value: WorkoutStore.durationText(workout.duration))
                    }
                }

                ForEach(workout.sortedExercises) { exercise in
                    ExerciseSection(
                        exercise: exercise,
                        previous: previous[exercise.name],
                        unit: unit,
                        isActive: workout.isActive,
                        remove: { remove(exercise) }
                    )
                }

                Section {
                    Button("Add exercise", systemImage: "plus") {
                        showingPicker = true
                    }
                    .font(.headline)
                }

                Section("Notes") {
                    TextField("How did it go?", text: $workout.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if !workout.isActive {
                    Section {
                        Button("Delete workout", role: .destructive) {
                            confirmingDiscard = true
                        }
                    }
                }
            }
            .navigationTitle(workout.isActive ? "Workout" : "Edit workout")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // An active workout keeps running when hidden; resume it from the Workouts tab.
                    Button(workout.isActive ? "Hide" : "Done") {
                        try? context.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Save as routine", systemImage: "square.and.arrow.down") {
                            WorkoutStore.saveAsRoutine(workout, context: context)
                            showingRoutineSaved = true
                        }
                        .disabled(workout.sortedExercises.isEmpty)
                        if workout.isActive {
                            Button("Discard workout", systemImage: "trash", role: .destructive) {
                                confirmingDiscard = true
                            }
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                if workout.isActive {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Finish") {
                            WorkoutStore.finish(workout, context: context)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { name, kind in
                    WorkoutStore.addExercise(named: name, kind: kind, to: workout, context: context)
                    try? context.save()
                }
            }
            .confirmationDialog(
                workout.isActive ? "Discard this workout?" : "Delete this workout?",
                isPresented: $confirmingDiscard,
                titleVisibility: .visible
            ) {
                Button(workout.isActive ? "Discard" : "Delete", role: .destructive) {
                    context.delete(workout)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its exercises and sets will be deleted.")
            }
            .alert("Saved as a routine", isPresented: $showingRoutineSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Start \u{201C}\(workout.name)\u{201D} any time from the Workouts tab.")
            }
            .task(id: workout.sortedExercises.map(\.name)) {
                loadPrevious()
            }
        }
    }

    private func loadPrevious() {
        var result: [String: WorkoutExercise] = [:]
        for exercise in workout.sortedExercises where result[exercise.name] == nil {
            result[exercise.name] = WorkoutStore.lastPerformance(of: exercise.name, before: workout.startedAt, context: context)
        }
        previous = result
    }

    private func remove(_ exercise: WorkoutExercise) {
        context.delete(exercise)
        // Close the gap so positions stay in order.
        for (index, other) in workout.sortedExercises.filter({ $0 !== exercise }).enumerated() {
            other.position = index
        }
        try? context.save()
    }

    /// "12:05" or "1:02:05"
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

/// One exercise: its sets (strength) or time and distance (cardio).
private struct ExerciseSection: View {
    @Bindable var exercise: WorkoutExercise
    let previous: WorkoutExercise?
    let unit: WeightUnit
    let isActive: Bool
    let remove: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            switch exercise.kind {
            case .strength:
                HStack(spacing: 8) {
                    Text("Set").frame(width: 30, alignment: .leading)
                    Text("Last time").frame(maxWidth: .infinity, alignment: .leading)
                    Text(unit.symbol).frame(width: 64)
                    Text("Reps").frame(width: 52)
                    if isActive { Color.clear.frame(width: 30, height: 1) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    SetRow(
                        set: set,
                        number: index + 1,
                        previous: previousSet(at: index),
                        unit: unit,
                        showsDone: isActive
                    )
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            context.delete(set)
                            try? context.save()
                        }
                    }
                }

                Button("Add set", systemImage: "plus") {
                    WorkoutStore.addSet(to: exercise, context: context)
                    try? context.save()
                }
                .font(.subheadline)

            case .cardio:
                NumberField(title: "Time", value: $exercise.durationMinutes, unit: "min")
                NumberField(title: "Distance", value: $exercise.distanceKm, unit: "km")
                if let previous {
                    Text("Last time: \(Self.cardioText(previous))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .textCase(nil)
                Spacer()
                Menu {
                    Button("Remove exercise", systemImage: "trash", role: .destructive, action: remove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
                .accessibilityLabel("Options for \(exercise.name)")
            }
        }
    }

    private func previousSet(at index: Int) -> WorkoutSet? {
        guard let sets = previous?.sortedSets, !sets.isEmpty else { return nil }
        return index < sets.count ? sets[index] : nil
    }

    static func cardioText(_ exercise: WorkoutExercise) -> String {
        var parts: [String] = []
        if exercise.durationMinutes > 0 {
            parts.append("\(exercise.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min")
        }
        if exercise.distanceKm > 0 {
            parts.append("\(exercise.distanceKm.formatted(.number.precision(.fractionLength(0...2)))) km")
        }
        return parts.isEmpty ? "–" : parts.joined(separator: " · ")
    }
}

/// One set: last time's numbers, then weight and reps you can type, and a tick while training.
private struct SetRow: View {
    @Bindable var set: WorkoutSet
    let number: Int
    let previous: WorkoutSet?
    let unit: WeightUnit
    let showsDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.rounded(.subheadline))
                .frame(width: 30, alignment: .leading)
            Text(previousText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            CompactNumberField(placeholder: "0", value: weight)
            CompactNumberField(placeholder: "0", value: reps, allowsDecimals: false, width: 52)
            if showsDone {
                Button {
                    set.isDone.toggle()
                } label: {
                    Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(set.isDone ? Theme.turquoise : Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .sensoryFeedback(.success, trigger: set.isDone) { _, isDone in isDone }
                .accessibilityLabel(set.isDone ? "Set \(number) done" : "Mark set \(number) done")
            }
        }
        .listRowBackground(highlight)
    }

    /// Done sets are tinted while you train.
    private var highlight: Color? {
        showsDone && set.isDone ? Theme.tint.opacity(0.6) : nil
    }

    /// "40 × 8" or "8 reps" (bodyweight), or a dash if there's nothing to compare.
    private var previousText: String {
        guard let previous else { return "–" }
        guard previous.weightKg > 0 else { return "\(previous.reps) reps" }
        let weight = unit.value(fromKg: previous.weightKg).formatted(.number.precision(.fractionLength(0...1)))
        return "\(weight) × \(previous.reps)"
    }

    private var weight: Binding<Double> {
        Binding(
            get: { unit.value(fromKg: set.weightKg) },
            set: { set.weightKg = max(unit.kg(from: $0), 0) }
        )
    }

    private var reps: Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(Int($0), 0) }
        )
    }
}
