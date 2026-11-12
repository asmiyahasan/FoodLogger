import SwiftUI

/// FoodLogger's palette. Each colour has one job:
/// turquoise = brand + water, orange = calories, deep orange = "look at this" (over goal, Check).
/// Light and dark versions live in Assets.xcassets.
enum Theme {
    static let turquoise = Color.accentColor
    static let tint = Color("BrandTint")
    static let track = Color("BrandTrack")
    static let turquoiseText = Color("BrandTurquoiseText")
    static let orange = Color("BrandOrange")
    static let orangeTrack = Color("BrandOrangeTrack")
    static let deepOrange = Color("BrandDeepOrange")
    static let deepOrangeText = Color("BrandDeepOrangeText")
}

extension Font {
    /// Rounded figures for numbers: friendly but precise.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

/// A small outlined tag, e.g. "Check".
struct TagLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(Capsule().stroke(Theme.deepOrange))
            .foregroundStyle(Theme.deepOrangeText)
    }
}

/// A slim progress bar that turns deep orange when over the goal.
struct GoalProgressBar: View {
    let fraction: Double
    var color: Color = Theme.turquoise
    var track: Color = Theme.track
    var height: CGFloat = 6

    private var isOver: Bool { fraction > 1.0001 }

    var body: some View {
        Capsule()
            .fill(track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(isOver ? Theme.deepOrange : color)
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
            }
            .animation(.easeOut, value: fraction)
            .accessibilityHidden(true)
    }
}

/// The app logo (the apple-and-ring icon), at any size.
struct AppLogo: View {
    var size: CGFloat = 40

    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: Theme.turquoise.opacity(0.25), radius: size * 0.12, y: size * 0.05)
            .accessibilityHidden(true)
    }
}

/// "Hi, Asmiya!", or "Hi there!" when no name is set.
func greeting(for name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "Hi there!" : "Hi, \(trimmed)!"
}

/// The logo gently pulsing, used while Claude analyses a meal.
struct PulsingLogo: View {
    var size: CGFloat = 26
    @State private var isPulsing = false

    var body: some View {
        AppLogo(size: size)
            .scaleEffect(isPulsing ? 1.1 : 0.9)
            .opacity(isPulsing ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
