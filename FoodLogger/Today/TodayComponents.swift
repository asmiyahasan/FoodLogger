import SwiftUI

/// Ring showing energy left (or over) against the daily goal.
struct EnergyRing: View {
    let consumedKcal: Double
    let goalKcal: Double
    let unit: EnergyUnit

    private var progress: Double { goalKcal > 0 ? min(consumedKcal / goalKcal, 1) : 0 }
    private var remainingKcal: Double { goalKcal - consumedKcal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    remainingKcal >= 0 ? Color.accentColor : Color.orange,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
            VStack(spacing: 2) {
                Text(unit.value(fromKcal: abs(remainingKcal)).formatted(.number.precision(.fractionLength(0))))
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(remainingKcal >= 0 ? "\(unit.symbol) left" : "\(unit.symbol) over")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One nutrient against its goal, e.g. "Protein 68 / 100 g".
struct GoalBar: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Self.whole(value)) / \(Self.whole(goal)) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.caption)
            ProgressView(value: goal > 0 ? min(value / goal, 1) : 0)
        }
    }

    static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

/// Water progress with one-tap add buttons and undo.
struct WaterCard: View {
    let totalMl: Double
    let goalMl: Double
    let quickSizes: [Double]
    let canUndo: Bool
    let add: (Double) -> Void
    let undo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("\(litresText(totalMl)) of \(litresText(goalMl)) L")
                    .monospacedDigit()
                Spacer()
            }
            ProgressView(value: goalMl > 0 ? min(totalMl / goalMl, 1) : 0)
                .tint(.blue)
            // An explicit button style keeps each button tappable on its own inside a List row.
            HStack {
                ForEach(Array(quickSizes.enumerated()), id: \.offset) { _, size in
                    Button {
                        add(size)
                    } label: {
                        Text("+\(size.formatted(.number.precision(.fractionLength(0)))) ml")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    undo()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(!canUndo)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A meal in the day's list.
struct MealRow: View {
    let meal: Meal
    let unit: EnergyUnit

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                    .lineLimit(1)
                Text("\(meal.mealType.label) · \(meal.timestamp.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if meal.status == .logged {
                Text(unit.format(kcal: meal.totals.energyKcal))
                    .font(.subheadline)
                    .monospacedDigit()
            } else {
                Text(meal.status == .pending ? "Pending" : "Review")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = meal.photo, let image = Image(imageData: data) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
