import SwiftUI
import SwiftData

/// Search my foods, the Australian database, Open Food Facts and USDA in one place.
struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.energyUnit) private var energyUnit: EnergyUnit = .kcal
    @Query(sort: \UserFood.lastUsed, order: .reverse) private var myFoods: [UserFood]

    let onPick: (FoodCandidate) -> Void

    @State private var query: String
    @State private var results: [FoodSource: SourceResult] = [:]
    @State private var barcode = ""
    @State private var barcodeResult: SourceResult = .idle
    @State private var expandedSources: Set<FoodSource> = []
    @State private var showingScanner = false

    enum SourceResult {
        case idle
        case loading
        case done([FoodCandidate])
        case message(String)
    }

    init(initialQuery: String = "", onPick: @escaping (FoodCandidate) -> Void) {
        _query = State(initialValue: initialQuery)
        self.onPick = onPick
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var myFoodMatches: [FoodCandidate] {
        Array(SavedFoodRanking.rank(myFoods.map(\.saved), for: trimmedQuery).prefix(10))
    }

    var body: some View {
        NavigationStack {
            List {
                if !myFoodMatches.isEmpty {
                    Section(FoodSource.mine.title) {
                        ForEach(myFoodMatches) { candidateRow($0) }
                    }
                }

                ForEach([FoodSource.afcd, .openFoodFacts, .usda], id: \.self) { source in
                    Section(source.title) {
                        resultRows(results[source] ?? .idle, source: source)
                    }
                }

                Section {
                    #if os(iOS)
                    Button("Scan with camera", systemImage: "barcode.viewfinder") {
                        showingScanner = true
                    }
                    #endif
                    HStack {
                        TextField("Barcode number", text: $barcode)
                            .decimalKeyboard()
                        Button("Look up") {
                            Task { await lookUpBarcode() }
                        }
                        .buttonStyle(.borderless)
                        .disabled(barcode.filter(\.isNumber).isEmpty)
                    }
                    resultRows(barcodeResult)
                } header: {
                    Text("Barcode")
                } footer: {
                    Text("Scan a packaged food, or type the numbers under its barcode.")
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerSheet { code in
                    barcode = code
                    Task { await lookUpBarcode() }
                }
            }
            #endif
            .searchable(text: $query, prompt: "Search foods")
            .task(id: query) { await runSearch() }
            .navigationTitle("Search foods")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func resultRows(_ result: SourceResult, source: FoodSource? = nil) -> some View {
        switch result {
        case .idle:
            Text("Type at least 2 letters to search.")
                .foregroundStyle(.secondary)
        case .loading:
            ProgressView()
        case .message(let text):
            Text(text)
                .foregroundStyle(.secondary)
        case .done(let foods):
            if foods.isEmpty {
                Text("No close match")
                    .foregroundStyle(.secondary)
            }
            let limit = (source == nil || source == .afcd || expandedSources.contains(source!)) ? foods.count : 5
            ForEach(foods.prefix(limit)) { candidateRow($0) }
            if foods.count > limit, let source {
                Button("Show \(foods.count - limit) more") {
                    expandedSources.insert(source)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func candidateRow(_ food: FoodCandidate) -> some View {
        Button {
            onPick(food)
            dismiss()
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .lineLimit(2)
                    Text(food.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(energyUnit.format(kcal: food.per100g.energyKcal)) / 100 g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Searching

    private func runSearch() async {
        let text = trimmedQuery
        guard text.count >= 2 else {
            results = [:]
            return
        }
        // Wait for typing to pause, so we don't hit rate limits.
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }

        results = [.afcd: .loading, .openFoodFacts: .loading, .usda: .loading]
        expandedSources = []

        async let afcd = searchAFCD(text)
        async let openFoodFacts = searchOpenFoodFacts(text)
        async let usda = searchUSDA(text)

        let afcdResult = await afcd
        guard !Task.isCancelled else { return }
        results[.afcd] = afcdResult

        let offResult = await openFoodFacts
        guard !Task.isCancelled else { return }
        results[.openFoodFacts] = offResult

        let usdaResult = await usda
        guard !Task.isCancelled else { return }
        results[.usda] = usdaResult
    }

    private func searchAFCD(_ text: String) async -> SourceResult {
        guard await AFCDDatabase.shared.isAvailable else {
            return .message("The Australian database isn't added to the app yet.")
        }
        return .done(await AFCDDatabase.shared.search(text))
    }

    private func searchOpenFoodFacts(_ text: String) async -> SourceResult {
        do {
            return .done(SearchRanking.rank(try await OpenFoodFactsClient().search(text), for: text))
        } catch {
            return .message(Self.describe(error))
        }
    }

    private func searchUSDA(_ text: String) async -> SourceResult {
        guard let key = APIKeys.value(for: .usdaAPIKey) else {
            return .message("Add your USDA API key in Settings to search USDA.")
        }
        do {
            return .done(SearchRanking.rank(try await USDAClient(apiKey: key).search(text), for: text))
        } catch {
            return .message(Self.describe(error))
        }
    }

    private func lookUpBarcode() async {
        barcodeResult = .loading
        do {
            let saved = myFoods.map { (basedOn: $0.basedOnFoodID, food: $0.candidate) }
            if let product = try await BarcodeLookup.find(barcode, savedFoods: saved) {
                barcodeResult = .done([product])
            } else {
                barcodeResult = .message("No product with that barcode. You can enter the label values yourself.")
            }
        } catch {
            barcodeResult = .message(Self.describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            return "Search cancelled."
        }
        if (error as? URLError)?.code == .notConnectedToInternet {
            return "You're offline. Try again when you're connected."
        }
        return error.localizedDescription
    }
}

#Preview {
    FoodSearchView { _ in }
        .modelContainer(for: [Meal.self, MealItem.self, UserFood.self, WaterEntry.self, WeightEntry.self], inMemory: true)
}
