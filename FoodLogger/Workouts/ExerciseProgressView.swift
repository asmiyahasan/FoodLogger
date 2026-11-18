import Charts
import SwiftData
import SwiftUI

/// Every exercise you've logged, most recent first.
struct ExerciseProgressListView: View {
    @Query private var exercises: [WorkoutExercise]

    private struct Item: Identifiable {
        let name: String
        let kind: ExerciseKind
        let last: Date
        let sessions: Int
        var id: String { name }
    }

    private var items: [Item] {
        var byName: [String: Item] = [:]
        for exercise in exercises {
            guard let workout = exercise.workout, !workout.isActive else { continue }
            let existing = byName[exercise.name]
            byName[exercise.name] = Item(
                name: exercise.name,
                kind: exercise.kind,
                last: max(existing?.last ?? .distantPast, workout.startedAt),
                sessions: (existing?.sessions ?? 0) + 1
            )
        }
        return byName.values.sorted { $0.last > $1.last }
    }

    var body: some View {
        List(items) { item in
            NavigationLink {
                ExerciseProgressView(name: item.name)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                    Text("\(item.sessions) \(item.sessions == 1 ? "session" : "sessions") · last \(item.last.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Exercise progress")
        .inlineNavigationTitle()
    }
}

/// One exercise over time: heaviest set (or most reps for bodyweight), or distance/time for cardio.
struct ExerciseProgressView: View {
    let name: String

    @AppStorage(SettingsKey.weightUnit) private var unit: WeightUnit = .kg
    @Query private var exercises: [WorkoutExercise]

    init(name: String) {
        self.name = name
        _exercises = Query(filter: #Predicate<WorkoutExercise> { $0.name == name })
    }

    private struct Session: Identifiable {
        let date: Date
        let exercise: WorkoutExercise
        var id: Date { date }
    }

    private var sessions: [Session] {
        exercises
            .compactMap { exercise in
                guard let workout = exercise.workout, !workout.isActive else { return nil }
                return Session(date: workout.startedAt, exercise: exercise)
            }
            .sorted { $0.date < $1.date }
    }

    private var kind: ExerciseKind { exercises.first?.kind ?? .strength }

    var body: some View {
        let sessions = self.sessions
        List {
            if sessions.isEmpty {
                Text("No finished sessions yet.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    chart(sessions)
                } footer: {
                    Text(chartCaption(sessions))
                }
                Section("Sessions") {
                    ForEach(sessions.reversed()) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.medium))
                            Text(detail(session.exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(name)
        .inlineNavigationTitle()
    }

    // MARK: - What to chart

    private enum Metric { case weight, reps, distance, minutes }

    private func metric(_ sessions: [Session]) -> Metric {
        switch kind {
        case .strength:
            let anyWeight = sessions.contains { $0.exercise.sortedSets.contains { $0.weightKg > 0 } }
            return anyWeight ? .weight : .reps
        case .cardio:
            let anyDistance = sessions.contains { $0.exercise.distanceKm > 0 }
            return anyDistance ? .distance : .minutes
        }
    }

    private func value(_ exercise: WorkoutExercise, _ metric: Metric) -> Double {
        switch metric {
        case .weight: unit.value(fromKg: exercise.sortedSets.map(\.weightKg).max() ?? 0)
        case .reps: Double(exercise.sortedSets.map(\.reps).max() ?? 0)
        case .distance: exercise.distanceKm
        case .minutes: exercise.durationMinutes
        }
    }

    private func chartCaption(_ sessions: [Session]) -> String {
        switch metric(sessions) {
        case .weight: "Heaviest set each session, in \(unit.symbol)."
        case .reps: "Most reps in a set each session."
        case .distance: "Distance each session, in km."
        case .minutes: "Minutes each session."
        }
    }

    private func chart(_ sessions: [Session]) -> some View {
        let metric = metric(sessions)
        return Chart(sessions) { session in
            LineMark(
                x: .value("Date", session.date, unit: .day),
                y: .value("Value", value(session.exercise, metric))
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Theme.turquoise)
            PointMark(
                x: .value("Date", session.date, unit: .day),
                y: .value("Value", value(session.exercise, metric))
            )
            .foregroundStyle(Theme.turquoise)
        }
        .frame(height: 200)
        .padding(.vertical, 6)
    }

    /// "40 × 8, 40 × 8, 42.5 × 6" or "32 min · 5.2 km".
    private func detail(_ exercise: WorkoutExercise) -> String {
        switch exercise.kind {
        case .strength:
            return exercise.sortedSets.map { set in
                guard set.weightKg > 0 else { return "\(set.reps)" }
                let weight = unit.value(fromKg: set.weightKg).formatted(.number.precision(.fractionLength(0...1)))
                return "\(weight) × \(set.reps)"
            }
            .joined(separator: ", ")
        case .cardio:
            var parts: [String] = []
            if exercise.durationMinutes > 0 {
                parts.append("\(exercise.durationMinutes.formatted(.number.precision(.fractionLength(0...1)))) min")
            }
            if exercise.distanceKm > 0 {
                parts.append("\(exercise.distanceKm.formatted(.number.precision(.fractionLength(0...2)))) km")
            }
            return parts.joined(separator: " · ")
        }
    }
}
