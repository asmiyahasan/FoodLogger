import SwiftUI

/// A labelled number input that updates its value on every keystroke
/// (so tapping Save never loses the last edit).
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""

    @State private var text = ""

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                    .decimalKeyboard()
                    .onChange(of: text) { _, newValue in
                        if let parsed = Self.parse(newValue) {
                            value = parsed
                        } else if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                            value = 0
                        }
                    }
                if !unit.isEmpty {
                    Text(unit).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { text = Self.display(value) }
        .onChange(of: value) { _, newValue in
            // Only rewrite the text when the value changed from outside (e.g. a saved food was picked).
            let current = Self.parse(text) ?? 0
            if abs(current - newValue) > 0.001 {
                text = Self.display(newValue)
            }
        }
    }

    static func display(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}
