import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A meal you've had recently, offered on Today so you can log it again in one tap.
struct MealSuggestion: Identifiable {
    /// The most recent time you had it.
    let meal: Meal
    /// How many times you've had it in the last two weeks.
    let count: Int
    var id: PersistentIdentifier { meal.persistentModelID }
}

/// Picks the meals you're most likely to want again.
enum MealSuggestions {
    static let lookbackDays = 14

    /// The same foods count as the same meal, whatever the amounts.
    static func signature(of meal: Meal) -> String {
        meal.sortedItems
            .map { $0.foodID.isEmpty ? $0.name.lowercased() : $0.foodID }
            .sorted()
            .joined(separator: "|")
    }

    /// Top meals from the last two weeks: most often eaten first, with a boost for ones you
    /// usually have at this time of day (breakfast in the morning, and so on). Meals already
    /// logged on the day you're viewing are left out.
    static func top(
        from recent: [Meal],
        excluding alreadyLogged: [Meal],
        mealType: MealType,
        limit: Int = 3
    ) -> [MealSuggestion] {
        let loggedToday = Set(alreadyLogged.map { signature(of: $0) })

        struct Group {
            var latest: Meal
            var count = 0
            var matchesType = false
        }
        var groups: [String: Group] = [:]
        for meal in recent where meal.status == .logged && !(meal.items ?? []).isEmpty {
            let key = signature(of: meal)
            guard !loggedToday.contains(key) else { continue }
            var group = groups[key] ?? Group(latest: meal)
            group.count += 1
            if meal.timestamp > group.latest.timestamp { group.latest = meal }
            if meal.mealType == mealType { group.matchesType = true }
            groups[key] = group
        }

        return groups.values
            .sorted { a, b in
                let scoreA = Double(a.count) + (a.matchesType ? 2 : 0)
                let scoreB = Double(b.count) + (b.matchesType ? 2 : 0)
                return scoreA != scoreB ? scoreA > scoreB : a.latest.timestamp > b.latest.timestamp
            }
            .prefix(limit)
            .map { MealSuggestion(meal: $0.latest, count: $0.count) }
    }
}

/// A row of recent meals as cards. Tap to log, or touch and hold to review first.
struct MealSuggestionsRow: View {
    let suggestions: [MealSuggestion]
    let unit: EnergyUnit
    let log: (Meal) -> Void
    let review: (Meal) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(suggestions) { suggestion in
                    Button {
                        log(suggestion.meal)
                    } label: {
                        card(suggestion)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Log now", systemImage: "plus") { log(suggestion.meal) }
                        Button("Review before logging", systemImage: "square.and.pencil") { review(suggestion.meal) }
                    }
                    .accessibilityHint("Logs this meal again. Touch and hold to review first.")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func card(_ suggestion: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                MealThumbnail(meal: suggestion.meal)
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.turquoiseText)
                    .frame(width: 30, height: 30)
                    .background(Theme.tint, in: Circle())
            }
            Text(suggestion.meal.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Text("\(unit.format(kcal: suggestion.meal.totals.energyKcal)) · \(detail(suggestion))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 172, height: 156, alignment: .topLeading)
        .background(Self.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private func detail(_ suggestion: MealSuggestion) -> String {
        suggestion.count > 1
            ? "\(suggestion.count)× lately"
            : suggestion.meal.timestamp.formatted(.relative(presentation: .named))
    }

    /// The same white (dark grey in Dark Mode) as the other cards on Today.
    private static var cardBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
