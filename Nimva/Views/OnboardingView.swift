import SwiftUI

// Root container for the 4-screen onboarding flow.
// Uses a paged TabView so screens slide horizontally — familiar, low-friction.
// @AppStorage persists completion across launches (UserDefaults under the hood).
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Flag HomeView reads once on first appear to auto-open AddEventView
    @AppStorage("openAddEventOnLaunch") private var openAddEventOnLaunch = false
    // Shown once after the last screen — never again after the user has seen it
    @AppStorage("hasSeenProTrialOffer") private var hasSeenProTrialOffer = false

    @State private var step = 0
    @State private var showingProTrial = false

    var body: some View {
        ZStack(alignment: .top) {
            NimvaColors.background.ignoresSafeArea()

            // Paged carousel — selection: $step keeps our step counter in sync
            // so the progress dots always match the visible screen
            TabView(selection: $step) {
                WelcomeScreen { advance() }
                    .tag(0)
                ConceptScreen(onNext: { advance() }, onSkip: { finish(addEvent: false) })
                    .tag(1)
                EnergyTagScreen { advance() }
                    .tag(2)
                ReadyScreen(onAddEvent: { finish(addEvent: true) }, onSkip: { finish(addEvent: false) })
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Progress dots — current step is a pill, completed steps are teal,
            // upcoming steps are muted purple
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    if i == step {
                        Capsule()
                            .fill(NimvaColors.purplePrimary)
                            .frame(width: 22, height: 6)
                    } else {
                        Circle()
                            .fill(i < step ? NimvaColors.teal : NimvaColors.purpleMuted)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
            .padding(.top, 60)
        }
        // Full-screen cover so the trial prompt feels like its own moment,
        // not a sheet that can be swiped away accidentally
        .fullScreenCover(isPresented: $showingProTrial) {
            ProTrialPromptView {
                hasSeenProTrialOffer = true
                withAnimation { hasCompletedOnboarding = true }
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.35)) { step = min(step + 1, 3) }
    }

    private func finish(addEvent: Bool) {
        openAddEventOnLaunch = addEvent
        // Show the trial prompt once before entering the app.
        // If already seen (e.g. user re-runs onboarding somehow), skip straight through.
        if hasSeenProTrialOffer {
            withAnimation { hasCompletedOnboarding = true }
        } else {
            showingProTrial = true
        }
    }
}

// MARK: - Screen 1: Welcome

private struct WelcomeScreen: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Wordmark
                    VStack(spacing: 10) {
                        Text("✦")
                            .font(.system(size: 36))
                            .foregroundStyle(NimvaColors.purplePrimary)

                        Text("Nimva")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Your week, balanced around you")
                            .font(.system(size: 15))
                            .foregroundStyle(NimvaColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 100)

                    // Three feature cards
                    VStack(spacing: 12) {
                        FeatureCard(
                            icon: "bolt.fill",
                            iconColor: NimvaColors.amber,
                            title: "Energy aware",
                            detail: "Tag events by how draining they feel — not just how long they take"
                        )
                        FeatureCard(
                            icon: "calendar.badge.checkmark",
                            iconColor: NimvaColors.teal,
                            title: "Auto scheduled",
                            detail: "Nimva places flexible events in the best slot based on your load"
                        )
                        FeatureCard(
                            icon: "sparkles",
                            iconColor: NimvaColors.purplePrimary,
                            title: "Gets smarter",
                            detail: "Learns your patterns over time and improves its suggestions"
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            Button(action: onNext) {
                Text("Get started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NimvaColors.purplePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

private struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NimvaColors.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(NimvaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Screen 2: The concept

private struct ConceptScreen: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    // Without Nimva: front-loaded, heavy Mon–Wed, empty Thu–Sun
    // With Nimva: spread evenly Mon–Fri
    private let before: [Double] = [0.95, 0.90, 0.85, 0.10, 0.05, 0.0, 0.0]
    private let after:  [Double] = [0.55, 0.50, 0.45, 0.60, 0.40, 0.0, 0.0]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Ember speech bubble
                    VStack(spacing: 0) {
                        EmberView(expression: .calm, size: .big)
                            .frame(width: 88, height: 88)

                        Text("Most apps manage your time.\nNimva manages your **energy**.")
                            .font(.system(size: 15))
                            .foregroundStyle(NimvaColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(NimvaColors.cardDark)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 8)
                    }
                    .padding(.top, 100)

                    // Before / after comparison
                    HStack(spacing: 16) {
                        MiniWeekGrid(label: "Without Nimva", loads: before, accentColor: NimvaColors.coral)
                        MiniWeekGrid(label: "With Nimva", loads: after, accentColor: NimvaColors.teal)
                    }

                    Text("Same events — distributed around your energy, not just around the clock.")
                        .font(.system(size: 13))
                        .foregroundStyle(NimvaColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("That makes sense")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NimvaColors.purplePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Skip intro")
                        .font(.system(size: 14))
                        .foregroundStyle(NimvaColors.textMuted)
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

// Simple bar chart — one bar per day showing relative load
private struct MiniWeekGrid: View {
    let label: String
    let loads: [Double]
    let accentColor: Color

    private let days = ["M","T","W","T","F","S","S"]
    private let maxHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(loads[i] < 0.01 ? NimvaColors.purpleMuted.opacity(0.3) : accentColor.opacity(0.7 + loads[i] * 0.3))
                            .frame(width: 16, height: max(4, maxHeight * CGFloat(loads[i])))
                        Text(days[i])
                            .font(.system(size: 8))
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                }
            }
            .frame(height: maxHeight + 16, alignment: .bottom)
        }
        .padding(14)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Screen 3: Energy tagging

// This screen directly addresses the #1 user confusion from early testing:
// people assumed the app would track energy automatically via sensors.
// The interactive chip lets them feel how tagging works before they leave onboarding.
private struct EnergyTagScreen: View {
    let onNext: () -> Void

    @State private var selectedChip: ChipOption? = nil

    enum ChipOption: String, CaseIterable {
        case alright = "Alright"
        case manageable = "Manageable"
        case takesEffort = "Takes Effort"
        case prettyDraining = "Pretty Draining"

        var color: Color {
            switch self {
            case .alright:       return NimvaColors.teal
            case .manageable:    return Color(hex: "5b9e6a")
            case .takesEffort:   return NimvaColors.amber
            case .prettyDraining: return NimvaColors.coral
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Text(selectedChip == nil ? "😌" : "😊")
                            .font(.system(size: 48))
                            .animation(.easeInOut(duration: 0.2), value: selectedChip != nil)

                        Text("One quick thing")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Nimva doesn't track your energy automatically")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NimvaColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("You tag each event once, and Nimva learns your patterns from there.")
                            .font(.system(size: 13))
                            .foregroundStyle(NimvaColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 100)

                    // Interactive example card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Circle()
                                .fill(NimvaColors.teal)
                                .frame(width: 8, height: 8)
                            Text("Study session")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(NimvaColors.textPrimary)
                            Spacer()
                            Text("Flexible")
                                .font(.system(size: 10))
                                .foregroundStyle(NimvaColors.textMuted)
                        }

                        Text("How draining does this feel? Tap one ↓")
                            .font(.system(size: 11))
                            .foregroundStyle(NimvaColors.textMuted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(ChipOption.allCases, id: \.self) { chip in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedChip = chip
                                    }
                                } label: {
                                    Text(chip.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(selectedChip == chip ? .white : chip.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedChip == chip ? chip.color : chip.color.opacity(0.12))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(chip.color.opacity(selectedChip == chip ? 0 : 0.4), lineWidth: 1))
                                }
                                // Minimum 44pt touch target
                                .frame(minHeight: 44)
                            }
                        }

                        if selectedChip != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NimvaColors.teal)
                                    .font(.system(size: 13))
                                Text("Nimva will remember this for future study sessions")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NimvaColors.teal)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(16)
                    .background(NimvaColors.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("You can always update energy labels later — and Nimva gets better the more you use it.")
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            Button(action: onNext) {
                Text("Got it")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NimvaColors.purplePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Screen 4: Ready

private struct ReadyScreen: View {
    let onAddEvent: () -> Void
    let onSkip: () -> Void

    @State private var showAddEvent = false

    private let steps = [
        ("1", "Add your fixed events", "Classes, meetings — anything with a set time"),
        ("2", "Add flexible tasks",    "Study sessions, gym, anything you can move around"),
        ("3", "Build your week",       "Nimva places everything based on your energy load"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Ember + heading
                    VStack(spacing: 12) {
                        EmberView(expression: .happy, size: .big)
                            .frame(width: 88, height: 88)
                            .padding(.top, 100)

                        Text("You're all set")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Here's how to get your first week built:")
                            .font(.system(size: 14))
                            .foregroundStyle(NimvaColors.textSecondary)
                    }

                    // Step checklist
                    VStack(spacing: 10) {
                        ForEach(steps, id: \.0) { number, title, subtitle in
                            HStack(spacing: 14) {
                                Text(number)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(NimvaColors.purplePrimary)
                                    .frame(width: 28, height: 28)
                                    .background(NimvaColors.purplePrimary.opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text(subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(NimvaColors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(NimvaColors.cardDark)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            VStack(spacing: 12) {
                Button {
                    showAddEvent = true
                } label: {
                    Text("Add my first event")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NimvaColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Maybe later")
                        .font(.system(size: 14))
                        .foregroundStyle(NimvaColors.textMuted)
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
        // Presenting AddEventView here so the user can add their first event
        // before being dropped into the main app — smoother first-run experience
        .sheet(isPresented: $showAddEvent, onDismiss: onAddEvent) {
            AddEventView()
        }
    }
}

#Preview {
    OnboardingView()
}
