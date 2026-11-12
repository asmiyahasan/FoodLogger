import SwiftUI

/// A short swipe-through of what FoodLogger does.
struct TutorialView: View {
    var finishTitle = "Start logging"
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let symbol: String
        let color: Color
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(symbol: "camera.fill", color: Theme.turquoise, title: "Log a meal",
             text: "Snap a photo and say what's in it, like \u{201C}chicken curry with rice and a roti\u{201D}. Packaged food? Scan the barcode. Claude finds each food in real nutrition databases, so the numbers are never made up."),
        Page(symbol: "checklist", color: Theme.orange, title: "Check and adjust",
             text: "Review every item before saving. Orange Check tags mark guesses. Change amounts in cups, pieces or grams, and resize whole dishes in one go."),
        Page(symbol: "drop.fill", color: Theme.turquoise, title: "Water in one tap",
             text: "Tap +250 ml or +500 ml on the Today screen. Turn on reminders in Goals, and log straight from the notification."),
        Page(symbol: "target", color: Theme.orange, title: "Your goals",
             text: "Set your calories, and your macros and fibre can follow automatically. Add a goal weight and log weigh-ins to see a smoothed trend. Tap the target button on Today any time."),
        Page(symbol: "sparkles", color: Theme.turquoise, title: "It learns you",
             text: "Foods, brands and recipes you log are remembered. Your usual amounts and corrections make every estimate better than the last."),
        Page(symbol: "widget.small", color: Theme.orange, title: "Add the widget",
             text: "See your water and calories left on your Home Screen, and tap +250 ml without opening the app. Touch and hold the Home Screen, tap Edit, then Add Widget, and search for FoodLogger."),
        Page(symbol: "waveform", color: Theme.turquoise, title: "Ask Siri",
             text: "Say \u{201C}Hey Siri, log water in FoodLogger\u{201D} or \u{201C}How many calories do I have left in FoodLogger?\u{201D} You'll find these in the Shortcuts app too."),
        Page(symbol: "externaldrive.fill", color: Theme.deepOrange, title: "Keep it safe",
             text: "Your data lives on this phone. Back up to iCloud Drive from Settings every so often."),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif

            Button {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLastPage ? finishTitle : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 150, height: 150)
                Image(systemName: page.symbol)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(page.color)
            }
            .accessibilityHidden(true)
            Text(page.title)
                .font(.rounded(.title, weight: .bold))
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    TutorialView {}
}
