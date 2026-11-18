import SwiftUI

/// A small number box for set rows (weight, reps). Updates on every keystroke.
struct CompactNumberField: View {
    let placeholder: String
    @Binding var value: Double
    var allowsDecimals = true
    var width: CGFloat = 64

    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(width: width)
            .padding(.vertical, 6)
            .background(Theme.tint.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .modifier(NumberKeyboard(allowsDecimals: allowsDecimals))
            .onAppear { text = Self.display(value) }
            .onChange(of: text) { _, newValue in
                let cleaned = newValue.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                if let parsed = Double(cleaned) {
                    value = allowsDecimals ? parsed : parsed.rounded()
                } else if cleaned.isEmpty {
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                if abs((Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0) - newValue) > 0.001 {
                    text = Self.display(newValue)
                }
            }
    }

    static func display(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

private struct NumberKeyboard: ViewModifier {
    let allowsDecimals: Bool

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
        content.keyboardType(allowsDecimals ? .decimalPad : .numberPad)
        #else
        content
        #endif
    }
}
