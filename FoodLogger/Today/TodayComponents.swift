import SwiftUI

/// Ring showing energy left (or over) against the daily goal.
struct EnergyRing: View {
    let consumedKcal: Double
    let goalKcal: Double
    let unit: EnergyUnit

    private var progress: Double { goalKcal > 0 ? min(consumedKcal / goalKcal, 1) : 0 }
    private var remainingKcal: Double { goalKcal - consumedKcal }
    private var isOver: Bool { remainingKcal < 0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.orangeTrack, lineWidth: 13)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? Theme.deepOrange : Theme.orange,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            VStack(spacing: 0) {
                Text(unit.value(fromKcal: abs(remainingKcal)).formatted(.number.precision(.fractionLength(0))))
                    .font(.rounded(.title, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(isOver ? Theme.deepOrangeText : Color.primary)
                Text(isOver ? "\(unit.symbol) over" : "\(unit.symbol) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One nutrient against its goal, e.g. "Protein 68 / 100 g". Turns deep orange when over.
struct GoalBar: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String

    private var fraction: Double { goal > 0 ? value / goal : 0 }
    private var isOver: Bool { fraction > 1.0001 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Self.whole(value)) / \(Self.whole(goal)) \(unit)")
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(isOver ? Theme.deepOrangeText : Color.secondary)
                    .monospacedDigit()
            }
            GoalProgressBar(fraction: fraction)
        }
        .accessibilityElement(children: .combine)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.turquoiseText)
                Spacer()
                Text("\(litresText(totalMl)) of \(litresText(goalMl)) L")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.turquoiseText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GoalProgressBar(fraction: goalMl > 0 ? min(totalMl / goalMl, 1) : 0, height: 8)
            // An explicit button style keeps each button tappable on its own inside a List row.
            HStack(spacing: 8) {
                ForEach(Array(quickSizes.enumerated()), id: \.offset) { _, size in
                    Button {
                        add(size)
                    } label: {
                        Text("+\(size.formatted(.number.precision(.fractionLength(0)))) ml")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    undo()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(!canUndo)
            }
            .tint(Theme.turquoise)
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.increase, trigger: totalMl)
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
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(meal.mealType.label) · \(meal.timestamp.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if meal.status == .logged {
                Text(unit.format(kcal: meal.totals.energyKcal))
                    .font(.rounded(.subheadline))
                    .monospacedDigit()
            } else {
                TagLabel(text: meal.status == .pending ? "Pending" : "Review")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = meal.photo, let image = Image(imageData: data) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.tint)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Theme.turquoise)
                }
        }
    }
}
