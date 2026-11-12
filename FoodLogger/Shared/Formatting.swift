import Foundation

/// e.g. "15 g" or "2.5 g"
func gramsText(_ grams: Double) -> String {
    "\(grams.formatted(.number.precision(.fractionLength(0...1)))) g"
}

/// e.g. "1.25 L"
func litresText(_ millilitres: Double) -> String {
    (millilitres / 1000).formatted(.number.precision(.fractionLength(0...2)))
}
