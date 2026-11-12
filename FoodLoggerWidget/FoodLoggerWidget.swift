import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Data

nonisolated struct TodayEntry: TimelineEntry {
    var date: Date
    var waterMl: Double
    var waterGoalMl: Double
    var eatenKcal: Double
    var goalKcal: Double
    var unitRaw: String

    var kcalLeft: Double { goalKcal - eatenKcal }
    var energyFraction: Double { goalKcal > 0 ? min(eatenKcal / goalKcal, 1) : 0 }
    var waterFraction: Double { waterGoalMl > 0 ? min(waterMl / waterGoalMl, 1) : 0 }

    static let sample = TodayEntry(
        date: .now, waterMl: 1250, waterGoalMl: 2500, eatenKcal: 760, goalKcal: 2000, unitRaw: "kcal"
    )
}

nonisolated struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { @MainActor in completion(TodayData.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entry = TodayData.load()
            // Refresh just after midnight so the totals reset for the new day.
            let tomorrow = Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)
            ) ?? .now.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(tomorrow.addingTimeInterval(60))))
        }
    }
}

enum TodayData {
    static func load() -> TodayEntry {
        // A fresh context each time, so changes made in the app are always picked up.
        let context = ModelContext(SharedStore.container)
        return TodayEntry(
            date: .now,
            waterMl: DailySnapshot.waterToday(context: context),
            waterGoalMl: DailySnapshot.waterGoalMl,
            eatenKcal: DailySnapshot.eatenToday(context: context).energyKcal,
            goalKcal: DailySnapshot.energyGoalKcal,
            unitRaw: DailySnapshot.energyUnit.rawValue
        )
    }
}

// MARK: - Widget

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSync.kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Water so far, a quick +250 ml button and calories left.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

enum WidgetColors {
    static let turquoise = Color.accentColor
    static let track = Color("BrandTrack")
    static let turquoiseText = Color("BrandTurquoiseText")
    static let orange = Color("BrandOrange")
    static let orangeTrack = Color("BrandOrangeTrack")
    static let deepOrange = Color("BrandDeepOrange")
    static let deepOrangeText = Color("BrandDeepOrangeText")
}

/// Amount the widget button adds.
private let quickWaterMl = 250

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

// MARK: - Pieces

private extension TodayEntry {
    var unit: EnergyUnit { EnergyUnit(rawValue: unitRaw) ?? .kcal }
    var isOver: Bool { kcalLeft < 0 }

    /// "1,240" (the number only)
    var energyNumber: String {
        unit.value(fromKcal: abs(kcalLeft)).formatted(.number.precision(.fractionLength(0)))
    }

    var energyCaption: String { isOver ? "\(unit.symbol) over" : "\(unit.symbol) left" }
    var waterText: String { "\(litresText(waterMl)) / \(litresText(waterGoalMl)) L" }
}

private struct AddWaterButton: View {
    var compact = false

    var body: some View {
        Button(intent: AddWaterIntent(millilitres: quickWaterMl)) {
            Label("\(quickWaterMl) ml", systemImage: "plus")
                .font(.system(compact ? .caption : .subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(WidgetColors.turquoise)
        .widgetAccentable()
    }
}

private struct Bar: View {
    let fraction: Double
    let fill: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 6 : 0))
                    .widgetAccentable()
            }
        }
        .frame(height: 6)
    }
}

private struct EnergyBlock: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Calories", systemImage: "flame.fill")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(WidgetColors.deepOrangeText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(entry.energyNumber)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(entry.isOver ? WidgetColors.deepOrange : .primary)
                    .contentTransition(.numericText())
                    .invalidatableContent()
                Text(entry.energyCaption)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Bar(fraction: entry.energyFraction,
                fill: entry.isOver ? WidgetColors.deepOrange : WidgetColors.orange,
                track: WidgetColors.orangeTrack)
        }
    }
}

private struct WaterBlock: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Water", systemImage: "drop.fill")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(WidgetColors.turquoiseText)
            Text(entry.waterText)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .invalidatableContent()
            Bar(fraction: entry.waterFraction, fill: WidgetColors.turquoise, track: WidgetColors.track)
        }
    }
}

// MARK: - Home screen

private struct SmallView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EnergyBlock(entry: entry)
            WaterBlock(entry: entry)
            Spacer(minLength: 0)
            AddWaterButton(compact: true)
        }
    }
}

private struct MediumView: View {
    let entry: TodayEntry

    var body: some View {
        HStack(spacing: 16) {
            // Calories ring
            ZStack {
                Circle().stroke(WidgetColors.orangeTrack, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: entry.energyFraction)
                    .stroke(entry.isOver ? WidgetColors.deepOrange : WidgetColors.orange,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                VStack(spacing: 0) {
                    Text(entry.energyNumber)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .invalidatableContent()
                    Text(entry.energyCaption)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
            }
            .frame(maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Today")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                WaterBlock(entry: entry)
                Spacer(minLength: 0)
                AddWaterButton()
            }
        }
    }
}

// MARK: - Lock screen

private struct RectangularView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(entry.energyNumber) \(entry.energyCaption)", systemImage: "flame.fill")
                .font(.system(.headline, design: .rounded))
                .widgetAccentable()
            Label(entry.waterText, systemImage: "drop.fill")
                .font(.system(.subheadline, design: .rounded))
            Gauge(value: entry.waterFraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CircularView: View {
    let entry: TodayEntry

    var body: some View {
        Gauge(value: entry.energyFraction) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text(entry.energyNumber)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry.sample
}
