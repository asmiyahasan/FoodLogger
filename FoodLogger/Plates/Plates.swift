import SwiftUI

/// A plate or bowl you eat from, used as a size reference in photos.
nonisolated struct Plate: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var diameterCm: Double

    var label: String { "\(name) (\(diameterCm.formatted(.number.precision(.fractionLength(0...1)))) cm)" }

    static let suggestions = [
        Plate(name: "Dinner plate", diameterCm: 27),
        Plate(name: "Side plate", diameterCm: 20),
        Plate(name: "Thali", diameterCm: 30),
        Plate(name: "Rice bowl", diameterCm: 15),
        Plate(name: "Cereal bowl", diameterCm: 17),
    ]
}

/// Saved in settings as JSON (included in backups).
nonisolated enum PlateStore {
    static func decode(_ json: String) -> [Plate] {
        (try? JSONDecoder().decode([Plate].self, from: Data(json.utf8))) ?? []
    }

    static func encode(_ plates: [Plate]) -> String {
        (try? String(data: JSONEncoder().encode(plates), encoding: .utf8)) ?? "[]"
    }
}

/// Settings → Plates & bowls
struct PlatesView: View {
    @AppStorage(SettingsKey.plates) private var platesJSON = "[]"
    @State private var newName = ""
    @State private var newDiameter: Double = 0

    private var plates: [Plate] { PlateStore.decode(platesJSON) }

    var body: some View {
        Form {
            Section {
                if plates.isEmpty {
                    Text("No plates yet. Add the ones you use most.")
                        .foregroundStyle(.secondary)
                }
                ForEach(plates) { plate in
                    LabeledContent(plate.name, value: "\(plate.diameterCm.formatted(.number.precision(.fractionLength(0...1)))) cm")
                }
                .onDelete { offsets in
                    var updated = plates
                    updated.remove(atOffsets: offsets)
                    platesJSON = PlateStore.encode(updated)
                }
            } header: {
                Text("Your plates and bowls")
            } footer: {
                Text("Measure straight across the top, rim to rim. When you snap a meal, pick what it's on so Claude can judge portion sizes from the real size.")
            }

            Section("Add one") {
                TextField("Name, e.g. Thali", text: $newName)
                NumberField(title: "Across", value: $newDiameter, unit: "cm")
                Button("Add", systemImage: "plus") {
                    add(Plate(name: newName.trimmingCharacters(in: .whitespaces), diameterCm: newDiameter))
                    newName = ""
                    newDiameter = 0
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newDiameter < 5)
            }

            let unused = Plate.suggestions.filter { suggestion in
                !plates.contains { $0.name.localizedCaseInsensitiveCompare(suggestion.name) == .orderedSame }
            }
            if !unused.isEmpty {
                Section {
                    ForEach(unused) { suggestion in
                        Button {
                            add(Plate(name: suggestion.name, diameterCm: suggestion.diameterCm))
                        } label: {
                            Label(suggestion.label, systemImage: "plus.circle")
                        }
                    }
                } header: {
                    Text("Common sizes")
                } footer: {
                    Text("Typical sizes. Measuring your own is more accurate.")
                }
            }
        }
        .navigationTitle("Plates & bowls")
        .inlineNavigationTitle()
    }

    private func add(_ plate: Plate) {
        var updated = plates
        updated.append(plate)
        platesJSON = PlateStore.encode(updated)
    }
}
