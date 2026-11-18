import SwiftData
import SwiftUI

/// The Workouts tab: the workout in progress, routines to start from, and history.
struct WorkoutsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.weightUnit) private var unit: WeightUnit = .kg
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \Routine.name) private var routines: [Routine]

    @State private var openWorkout: Workout?
    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false

    private var active: Workout? { workouts.first { $0.isActive } }
    private var finished: [Workout] { workouts.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if let active {
                    Section {
                        Button {
                            openWorkout = active
                        } label: {
                            ActiveWorkoutRow(workout: active)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button {
                        start(nil)
                    } label: {
                        Label("Start empty workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .disabled(active != nil)
                } footer: {
                    if active != nil {
                        Text("Finish your current workout to start another.")
                    }
                }

                Section {
                    ForEach(routines) { routine in
                        Button {
                            start(routine)
                        } label: {
                            RoutineRow(routine: routine)
                        }
                        .buttonStyle(.plain)
                        .disabled(active != nil)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(routine)
                                try? context.save()
                            }
                            Button("Edit", systemImage: "pencil") {
                                editingRoutine = routine
                            }
                            .tint(Theme.orange)
                        }
                        .contextMenu {
                            Button("Start", systemImage: "play.fill") { start(routine) }
                                .disabled(active != nil)
                            Button("Edit", systemImage: "pencil") { editingRoutine = routine }
                        }
                    }
                    Button("New routine", systemImage: "plus") {
                        creatingRoutine = true
                    }
                } header: {
                    Text("Routines")
                } footer: {
                    Text(routines.isEmpty
                         ? "Save your usual sessions, like \u{201C}Push day\u{201D}, to start them in one tap."
                         : "Tap a routine to start it. Swipe to edit or delete.")
                }

                Section("History") {
                    if finished.isEmpty {
                        Text("No workouts yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(finished.prefix(60)) { workout in
                        Button {
                            openWorkout = workout
                        } label: {
                            WorkoutRow(workout: workout, unit: unit)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(workout)
                                try? context.save()
                            }
                        }
                    }
                }

                if !finished.isEmpty {
                    Section {
                        NavigationLink {
                            ExerciseProgressListView()
                        } label: {
                            Label("Exercise progress", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .sheet(item: $openWorkout) { workout in
                WorkoutEditorView(workout: workout)
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
            }
            .sheet(isPresented: $creatingRoutine) {
                RoutineEditorView(routine: nil)
            }
        }
    }

    private func start(_ routine: Routine?) {
        openWorkout = WorkoutStore.start(routine: routine, context: context)
    }
}

private struct ActiveWorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.turquoise, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("In progress · \(WorkoutEditorView.clock(workout.duration))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            Text("Resume")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.turquoiseText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.body.weight(.medium))
                Text(routine.exercises.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.turquoise)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct WorkoutRow: View {
    let workout: Workout
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(workout.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(workout.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(WorkoutStore.durationText(workout.duration)) · \(WorkoutStore.summary(of: workout, unit: unit))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [Workout.self, WorkoutExercise.self, WorkoutSet.self, Routine.self], inMemory: true)
}
