import SwiftUI
import SwiftData

/// Scan → look up → review. For packaged food straight from the Today screen.
struct BarcodeLogView: View {
    let defaultDate: Date

    @Environment(\.dismiss) private var dismiss
    @Query private var myFoods: [UserFood]

    @State private var phase: Phase = .scanning

    enum Phase {
        case scanning
        case lookingUp(String)
        case review(DraftItem)
        case failed(String)
    }

    var body: some View {
        switch phase {
        case .scanning:
            #if os(iOS)
            BarcodeScannerSheet(dismissOnScan: false) { code in
                Task { await lookUp(code) }
            }
            #else
            ContentUnavailableView("Scanning needs an iPhone or iPad", systemImage: "barcode.viewfinder")
            #endif
        case .lookingUp(let code):
            VStack(spacing: 16) {
                PulsingLogo(size: 48)
                Text("Looking up \(code)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review(let draft):
            MealEditorView(defaultDate: defaultDate, drafts: [draft])
        case .failed(let message):
            NavigationStack {
                ContentUnavailableView {
                    Label("Couldn't look it up", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Scan again") { phase = .scanning }
                        .buttonStyle(.borderedProminent)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }

    private func lookUp(_ code: String) async {
        phase = .lookingUp(code)
        let saved = myFoods.map { (basedOn: $0.basedOnFoodID, food: $0.candidate) }
        do {
            if let food = try await BarcodeLookup.find(code, savedFoods: saved) {
                phase = .review(DraftItem(
                    name: food.name,
                    grams: food.servingGrams ?? 100,
                    per100g: food.per100g,
                    foodID: food.id,
                    sourceLabel: food.source.shortLabel,
                    origin: .user,
                    confidence: 1,
                    matchedName: food.name
                ))
            } else {
                // Not in Open Food Facts: enter the label once, then save it to My foods.
                phase = .review(DraftItem(
                    name: "",
                    grams: 100,
                    per100g: Nutrients(),
                    foodID: BarcodeLookup.foodID(for: code),
                    sourceLabel: "Barcode \(code)",
                    origin: .user,
                    confidence: 0,
                    saveToMyFoods: true,
                    note: "Not found in Open Food Facts. Tap to enter the label values."
                ))
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
