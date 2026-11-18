import Foundation
import SwiftData

/// Starting workouts and adding exercises, pre-filled from what you did last time.
enum WorkoutStore {
    /// Starts a workout, empty or from a routine.
    @discardableResult
    static func start(routine: Routine?, context: ModelContext) -> Workout {
        let workout = Workout(name: routine?.name ?? defaultName(), routineID: routine?.uuid.uuidString ?? "")
        context.insert(workout)
        if let routine {
            routine.lastUsed = .now
            for planned in routine.exercises {
                addExercise(named: planned.name, kind: planned.kind, to: workout, context: context,
                            targetSets: planned.sets, targetReps: planned.reps, targetMinutes: planned.minutes)
            }
        }
        try? context.save()
        return workout
    }

    /// "Morning workout", "Evening workout"…
    static func defaultName(at date: Date = .now) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Morning workout"
        case 12..<17: "Afternoon workout"
        default: "Evening workout"
        }
    }

    /// Adds an exercise. Sets copy the weights and reps from the last time you did it;
    /// a routine's targets decide how many sets, and the reps when there's no history.
    static func addExercise(
        named name: String,
        kind: ExerciseKind,
        to workout: Workout,
        context: ModelContext,
        targetSets: Int? = nil,
        targetReps: Int? = nil,
        targetMinutes: Double? = nil
    ) {
        let exercise = WorkoutExercise(name: name, kind: kind, position: (workout.exercises ?? []).count)
        context.insert(exercise)
        exercise.workout = workout

        let previous = lastPerformance(of: name, before: workout.startedAt, context: context)
        switch kind {
        case .strength:
            let previousSets = previous?.sortedSets ?? []
            let count = targetSets ?? max(previousSets.count, 3)
            for index in 0..<max(count, 1) {
                let template = previousSets.isEmpty ? nil : previousSets[min(index, previousSets.count - 1)]
                let set = WorkoutSet(
                    position: index,
                    reps: template?.reps ?? targetReps ?? 10,
                    weightKg: template?.weightKg ?? 0
                )
                context.insert(set)
                set.exercise = exercise
            }
        case .cardio:
            exercise.durationMinutes = previous?.durationMinutes ?? targetMinutes ?? 0
            exercise.distanceKm = previous?.distanceKm ?? 0
        }
    }

    /// The most recent finished time you did this exercise.
    static func lastPerformance(of name: String, before date: Date, context: ModelContext) -> WorkoutExercise? {
        let descriptor = FetchDescriptor<WorkoutExercise>(predicate: #Predicate { $0.name == name })
        let matches = (try? context.fetch(descriptor)) ?? []
        return matches
            .filter { exercise in
                guard let workout = exercise.workout else { return false }
                return !workout.isActive && workout.startedAt < date
            }
            .max { ($0.workout?.startedAt ?? .distantPast) < ($1.workout?.startedAt ?? .distantPast) }
    }

    /// Adds a set copying the one before it.
    static func addSet(to exercise: WorkoutExercise, context: ModelContext) {
        let last = exercise.sortedSets.last
        let set = WorkoutSet(position: (last?.position ?? -1) + 1, reps: last?.reps ?? 10, weightKg: last?.weightKg ?? 0)
        context.insert(set)
        set.exercise = exercise
    }

    /// Ends the workout, dropping empty sets and exercises. A workout with nothing in it is deleted.
    /// Returns whether the workout was kept.
    @discardableResult
    static func finish(_ workout: Workout, context: ModelContext) -> Bool {
        let kept = workout.sortedExercises.filter { exercise in
            switch exercise.kind {
            case .strength: exercise.sortedSets.contains { $0.reps > 0 }
            case .cardio: exercise.durationMinutes > 0 || exercise.distanceKm > 0
            }
        }
        guard !kept.isEmpty else {
            context.delete(workout)
            try? context.save()
            return false
        }
        for exercise in workout.sortedExercises {
            switch exercise.kind {
            case .strength:
                let empty = exercise.sortedSets.filter { $0.reps <= 0 }
                if empty.count == exercise.sortedSets.count {
                    context.delete(exercise)
                } else {
                    for set in empty { context.delete(set) }
                }
            case .cardio:
                if exercise.durationMinutes <= 0 && exercise.distanceKm <= 0 { context.delete(exercise) }
            }
        }
        workout.endedAt = .now
        try? context.save()
        return true
    }

    /// Makes a routine from a workout: same exercises, set counts and reps.
    static func saveAsRoutine(_ workout: Workout, context: ModelContext) -> Routine {
        let routine = Routine(name: workout.name, exercises: workout.sortedExercises.map { exercise in
            RoutineExercise(
                name: exercise.name,
                kind: exercise.kind,
                sets: max(exercise.sortedSets.count, 1),
                reps: exercise.sortedSets.first?.reps ?? 10,
                minutes: exercise.durationMinutes
            )
        })
        context.insert(routine)
        workout.routineID = routine.uuid.uuidString
        try? context.save()
        return routine
    }

    /// "5 exercises · 15 sets · 6,240 kg" or "Running 5.2 km".
    static func summary(of workout: Workout, unit: WeightUnit) -> String {
        let exercises = workout.sortedExercises
        let strength = exercises.filter { $0.kind == .strength }
        let cardio = exercises.filter { $0.kind == .cardio }
        var parts: [String] = []
        if exercises.count == 1, let only = exercises.first {
            parts.append(only.name)
        } else if !exercises.isEmpty {
            parts.append("\(exercises.count) exercises")
        }
        let sets = strength.flatMap(\.sortedSets)
        if !sets.isEmpty {
            parts.append("\(sets.count) sets")
            let volume = sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            if volume > 0 {
                parts.append("\(unit.value(fromKg: volume).formatted(.number.precision(.fractionLength(0)))) \(unit.symbol)")
            }
        }
        let km = cardio.reduce(0) { $0 + $1.distanceKm }
        if km > 0 { parts.append("\(km.formatted(.number.precision(.fractionLength(0...1)))) km") }
        return parts.isEmpty ? "No exercises" : parts.joined(separator: " · ")
    }

    /// "52 min" or "1 h 5 min".
    static func durationText(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval / 60), 0)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
}
