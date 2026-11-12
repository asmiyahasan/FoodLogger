import SwiftUI

/// First launch: your name, then your goals.
struct OnboardingView: View {
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.hasSeenTutorial) private var hasSeenTutorial = false

    @State private var step = 0
    @State private var nameInput = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { nameInput.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    welcome
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else if step == 1 {
                    goals
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    TutorialView {
                        hasSeenTutorial = true
                        hasCompletedOnboarding = true
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
        .onAppear { nameInput = userName }
    }

    // MARK: - Step 1: name

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            AppLogo(size: 120)
            VStack(spacing: 8) {
                Text("Welcome to FoodLogger")
                    .font(.rounded(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    // Wrap onto a second line instead of cutting off with "..." when the keyboard takes up space.
                    .fixedSize(horizontal: false, vertical: true)
                Text("Snap a meal, say what's in it, and you're done.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(.headline)
                TextField("Your name", text: $nameInput)
                    .font(.title3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.tint, in: RoundedRectangle(cornerRadius: 14))
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .onSubmit(continueToGoals)
            }
            .padding(.top, 12)

            Spacer()

            Button(action: continueToGoals) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(trimmedName.isEmpty)
        }
        .padding(24)
        .onAppear { nameFocused = true }
    }

    private func continueToGoals() {
        guard !trimmedName.isEmpty else { return }
        userName = trimmedName
        nameFocused = false
        step = 1
    }

    // MARK: - Step 2: goals

    private var goals: some View {
        GoalsView(
            intro: "Nice to meet you, \(userName)! Set your daily goals. You can change them any time.",
            showsReset: false
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { step = 0 }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                step = 2
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    OnboardingView()
}
