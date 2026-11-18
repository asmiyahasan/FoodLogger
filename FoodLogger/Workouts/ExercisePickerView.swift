import SwiftData
import SwiftUI

/// Pick an exercise: ones you've done recently, the built-in list, or a new one by name.
struct ExercisePickerView: View {
    let onPick: (String, ExerciseKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutExercise.name) private var done: [WorkoutExercise]
    @State private var query = ""
    @State private var newKind: ExerciseKind = .strength

    /// Exercises you've logged, most recent first, each name once.
    private var recent: [RecentExercise] {
        var seen = Set<String>()
        return done
            .sorted { ($0.workout?.startedAt ?? .distantPast) > ($1.workout?.startedAt ?? .distantPast) }
            .compactMap { exercise in
                seen.insert(exercise.name.lowercased()).inserted
                    ? RecentExercise(name: exercise.name, kind: exercise.kind)
                    : nil
            }
    }

    private struct RecentExercise: Identifiable {
        let name: String
        let kind: ExerciseKind
        var id: String { name }
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ name: String) -> Bool {
        trimmedQuery.isEmpty || name.localizedCaseInsensitiveContains(trimmedQuery)
    }

    /// Whether the typed name is already an exercise (so "Add" isn't offered twice).
    private var isKnownName: Bool {
        let name = trimmedQuery.lowercased()
        return recent.contains { $0.name.lowercased() == name }
            || ExerciseLibrary.all.contains { $0.name.lowercased() == name }
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedQuery.isEmpty && !isKnownName {
                    Section {
                        Picker("Type", selection: $newKind) {
                            ForEach(ExerciseKind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Button("Add \u{201C}\(trimmedQuery)\u{201D}", systemImage: "plus") {
                            pick(trimmedQuery, newKind)
                        }
                    } header: {
                        Text("New exercise")
                    }
                }

                let recentMatches = recent.filter { matches($0.name) }.prefix(8)
                if !recentMatches.isEmpty {
                    Section("Recent") {
                        ForEach(Array(recentMatches)) { item in
                            row(item.name, item.kind)
                        }
                    }
                }

                ForEach(ExerciseLibrary.groups, id: \.self) { group in
                    let entries = ExerciseLibrary.all.filter { $0.group == group && matches($0.name) }
                    if !entries.isEmpty {
                        Section(group) {
                            ForEach(entries) { entry in
                                row(entry.name, entry.kind)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search or type a new exercise")
            .navigationTitle("Add exercise")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ name: String, _ kind: ExerciseKind) -> some View {
        Button {
            pick(name, kind)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: kind == .strength ? "dumbbell" : "figure.run")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(kind.label)
            }
        }
    }

    private func pick(_ name: String, _ kind: ExerciseKind) {
        onPick(name, kind)
        dismiss()
    }
}
