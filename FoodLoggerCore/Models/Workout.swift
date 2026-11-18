import Foundation
import SwiftData

/// How an exercise is measured.
nonisolated enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Sets of reps at a weight (bench press, squats, push-ups).
    case strength
    /// Time and optional distance (running, cycling, plank, yoga).
    case cardio

    var id: String { rawValue }
    var label: String {
        switch self {
        case .strength: "Sets & reps"
        case .cardio: "Time & distance"
        }
    }
}

/// One training session. `endedAt` is nil while it's in progress.
@Model
final class Workout {
    var startedAt: Date = Date.now
    var endedAt: Date?
    var name: String = ""
    var notes: String = ""
    /// The routine it was started from, if any (Routine.uuid as a string).
    var routineID: String = ""
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]? = []

    init(name: String, startedAt: Date = .now, routineID: String = "") {
        self.name = name
        self.startedAt = startedAt
        self.routineID = routineID
    }

    var isActive: Bool { endedAt == nil }

    var sortedExercises: [WorkoutExercise] {
        (exercises ?? []).sorted { $0.position < $1.position }
    }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }
}

/// An exercise within a workout. Strength exercises have sets; cardio ones have time and distance.
@Model
final class WorkoutExercise {
    var name: String = ""
    var kindRaw: String = ExerciseKind.strength.rawValue
    var position: Int = 0
    var durationMinutes: Double = 0
    var distanceKm: Double = 0
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]? = []

    init(name: String, kind: ExerciseKind, position: Int) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.position = position
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    var sortedSets: [WorkoutSet] {
        (sets ?? []).sorted { $0.position < $1.position }
    }
}

/// One set: reps at a weight. Weight is always stored in kilograms (0 = bodyweight).
@Model
final class WorkoutSet {
    var position: Int = 0
    var reps: Int = 0
    var weightKg: Double = 0
    var isDone: Bool = false
    var exercise: WorkoutExercise?

    init(position: Int, reps: Int, weightKg: Double) {
        self.position = position
        self.reps = reps
        self.weightKg = weightKg
    }
}

/// A saved plan, e.g. "Push day": exercises with target sets and reps.
@Model
final class Routine {
    var uuid: UUID = UUID()
    var name: String = ""
    var exercises: [RoutineExercise] = []
    var createdAt: Date = Date.now
    var lastUsed: Date?

    init(name: String, exercises: [RoutineExercise] = []) {
        self.name = name
        self.exercises = exercises
    }
}

nonisolated struct RoutineExercise: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var kind: ExerciseKind
    var sets: Int = 3
    var reps: Int = 10
    /// Target minutes for cardio.
    var minutes: Double = 0
}
