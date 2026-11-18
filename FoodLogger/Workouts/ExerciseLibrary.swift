import Foundation

/// Common exercises to pick from. You can also add your own by name.
nonisolated enum ExerciseLibrary {
    struct Entry: Identifiable, Hashable, Sendable {
        let name: String
        let kind: ExerciseKind
        let group: String
        var id: String { name }
    }

    static let groups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Mind & body"]

    static let all: [Entry] = {
        func strength(_ group: String, _ names: [String]) -> [Entry] {
            names.map { Entry(name: $0, kind: .strength, group: group) }
        }
        func timed(_ group: String, _ names: [String]) -> [Entry] {
            names.map { Entry(name: $0, kind: .cardio, group: group) }
        }
        return strength("Chest", ["Bench press", "Incline dumbbell press", "Dumbbell bench press", "Chest fly", "Push-up", "Chest press machine"])
            + strength("Back", ["Deadlift", "Pull-up", "Chin-up", "Lat pulldown", "Barbell row", "Dumbbell row", "Seated cable row"])
            + strength("Legs", ["Squat", "Goblet squat", "Leg press", "Romanian deadlift", "Lunge", "Bulgarian split squat",
                                "Hip thrust", "Glute bridge", "Leg curl", "Leg extension", "Calf raise"])
            + strength("Shoulders", ["Overhead press", "Dumbbell shoulder press", "Lateral raise", "Rear delt fly", "Face pull"])
            + strength("Arms", ["Bicep curl", "Hammer curl", "Tricep pushdown", "Skull crusher", "Overhead tricep extension", "Dips"])
            + strength("Core", ["Crunch", "Hanging leg raise", "Russian twist", "Cable crunch"])
            + timed("Core", ["Plank", "Side plank"])
            + timed("Cardio", ["Running", "Walking", "Cycling", "Indoor cycling", "Rowing", "Swimming",
                               "Elliptical", "Stair climber", "Jump rope", "HIIT", "Hiking"])
            + timed("Mind & body", ["Yoga", "Pilates", "Stretching"])
    }()

    static func kind(of name: String) -> ExerciseKind? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.kind
    }
}
