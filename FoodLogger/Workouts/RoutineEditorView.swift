import SwiftData
import SwiftUI

/// Create or edit a routine: a name and a list of exercises with target sets and reps.
struct RoutineEditorView: View {
    /// nil to create a new routine.
    let routine: Routine?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var exercises: [RoutineExercise]
    @State private var showingPicker = false
    @State private var confirmingDelete = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _exercises = State(initialValue: routine?.exercises ?? [])
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name, e.g. Push day", text: $name)
                }

                Section {
                    ForEach($exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(.body.weight(.medium))
                            switch exercise.kind {
                            case .strength:
                                Stepper("\(exercise.sets) sets", value: $exercise.sets, in: 1...10)
                                Stepper("\(exercise.reps) reps", value: $exercise.reps, in: 1...50)
                            case .cardio:
                                Stepper(
                                    "\(Int(exercise.minutes)) min",
                                    value: $exercise.minutes,
                                    in: 0...240,
                                    step: 5
                                )
                            }
                        }
                        .font(.subheadline)
                        .padding(.vertical, 2)
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button("Add exercise", systemImage: "plus") {
                        showingPicker = true
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("When you start this routine, weights and reps are filled in from the last time you did each exercise.")
                }

                if routine != nil {
                    Section {
                        Button("Delete routine", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                        .disabled(exercises.count < 2)
                }
                #endif
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { name, kind in
                    exercises.append(RoutineExercise(name: name, kind: kind, minutes: kind == .cardio ? 30 : 0))
                }
            }
            .confirmationDialog("Delete this routine?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let routine { context.delete(routine) }
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Workouts you've already done with it are kept.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let routine {
            routine.name = trimmed
            routine.exercises = exercises
        } else {
            context.insert(Routine(name: trimmed, exercises: exercises))
        }
        try? context.save()
        dismiss()
    }
}
