import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var myFoods: [UserFood]

    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @AppStorage(SettingsKey.keepMealPhotos) private var keepMealPhotos = true
    @AppStorage(SettingsKey.goalEnergyKcal) private var goalEnergy = GoalDefaults.energyKcal

    @State private var usdaKeyInput = ""
    @State private var hasUSDAKey = KeychainStore.read(.usdaAPIKey) != nil
    private let usdaKeyInSecretsFile = APIKeys.fromSecretsFile(.usdaAPIKey) != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    LabeledContent("Name") {
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Units") {
                    Picker("Energy", selection: $energyUnit) {
                        ForEach(EnergyUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        LabeledContent {
                            Text(energyUnit.format(kcal: goalEnergy))
                        } label: {
                            Label("Goals", systemImage: "target")
                        }
                    }
                }

                Section {
                    Toggle("Keep meal photos", isOn: $keepMealPhotos)
                } footer: {
                    Text("When off, a meal's photo is deleted once the meal is logged.")
                }

                Section {
                    if hasUSDAKey {
                        LabeledContent("API key", value: "Saved")
                        Button("Remove key", role: .destructive) {
                            KeychainStore.delete(.usdaAPIKey)
                            hasUSDAKey = false
                        }
                    } else if usdaKeyInSecretsFile {
                        LabeledContent("API key", value: "Set in Secrets.plist")
                    } else {
                        SecureField("Paste your API key", text: $usdaKeyInput)
                        Button("Save key") {
                            let key = usdaKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            hasUSDAKey = KeychainStore.save(key, for: .usdaAPIKey)
                            usdaKeyInput = ""
                        }
                        .disabled(usdaKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("USDA FoodData Central")
                } footer: {
                    Text("Stored only in this device's Keychain. Get a free key at fdc.nal.usda.gov.")
                }

                Section("My foods") {
                    NavigationLink {
                        MyFoodsView()
                    } label: {
                        LabeledContent("Saved foods", value: "\(myFoods.count)")
                    }
                }

                Section {
                    HStack(spacing: 14) {
                        AppLogo(size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FoodLogger")
                                .font(.rounded(.headline, weight: .bold))
                            Text("Version \(Self.appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Data sources") {
                    Text("Australian Food Composition Database, Release 3 © Food Standards Australia New Zealand, licensed under CC BY 4.0.")
                    Text("Open Food Facts data © Open Food Facts contributors, licensed under the Open Database License.")
                    Text("USDA FoodData Central, U.S. Department of Agriculture (public domain).")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension SettingsView {
    static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct MyFoodsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @Query(sort: \UserFood.name) private var foods: [UserFood]

    var body: some View {
        List {
            if foods.isEmpty {
                ContentUnavailableView(
                    "No saved foods",
                    systemImage: "star",
                    description: Text("Turn on Save to my foods when adding an item.")
                )
            }
            ForEach(foods) { food in
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                    Text("\(energyUnit.format(kcal: food.nutrientsPer100g.energyKcal)) per 100 g · usually \(gramsText(food.defaultGrams))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(foods[index])
                }
            }
        }
        .navigationTitle("My foods")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self], inMemory: true)
}
