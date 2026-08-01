import SwiftUI
import EventKit
import SwiftData

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
                EnergyAnchorScreen(onNext: { advance() }, onSkip: { advance() })
                    .tag(3)
                ReadyScreen(onAddEvent: { finish(addEvent: true) }, onSkip: { finish(addEvent: false) })
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Progress dots — current step is a pill, completed steps are teal,
            // upcoming steps are muted purple
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
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
        withAnimation(.easeInOut(duration: 0.35)) { step = min(step + 1, 4) }
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
                            .font(NimvaFont.largeDisplay)
                            .foregroundStyle(NimvaColors.purplePrimary)

                        Text("Nimva")
                            .font(NimvaFont.largeDisplay)
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Your week, balanced around you")
                            .font(.system(.subheadline))
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
                    .font(NimvaFont.button)
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
                .font(.system(.title3))
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NimvaFont.bodySemi)
                    .foregroundStyle(NimvaColors.textPrimary)
                Text(detail)
                    .font(.system(.caption))
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
                            .font(.system(.subheadline))
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
                        .font(NimvaFont.body)
                        .foregroundStyle(NimvaColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("That makes sense")
                        .font(NimvaFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NimvaColors.purplePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Skip intro")
                        .font(NimvaFont.callout)
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
                .font(NimvaFont.chip)
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
                            .font(NimvaFont.micro)
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
        case noEnergy = "No energy"
        case alright = "Alright"
        case manageable = "Manageable"
        case takesEffort = "Takes Effort"
        case prettyDraining = "Pretty Draining"

        var color: Color {
            switch self {
            case .noEnergy:       return NimvaColors.textMuted
            case .alright:        return NimvaColors.teal
            case .manageable:     return Color(hex: "5b9e6a")
            case .takesEffort:    return NimvaColors.amber
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
                        EmberView(expression: selectedChip == nil ? .calm : .happy, size: .big)
                            .frame(width: 88, height: 88)
                            .animation(.easeInOut(duration: 0.2), value: selectedChip != nil)

                        Text("One quick thing")
                            .font(NimvaFont.greeting)
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Nimva doesn't track your energy automatically")
                            .font(NimvaFont.cardTitle)
                            .foregroundStyle(NimvaColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("You tag each event once, and Nimva learns your patterns from there.")
                            .font(NimvaFont.body)
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
                                .font(NimvaFont.calloutMed)
                                .foregroundStyle(NimvaColors.textPrimary)
                            Spacer()
                            Text("Flexible")
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)
                        }

                        Text("How draining does this feel? Tap one ↓")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)

                        VStack(spacing: 8) {
                            ForEach(ChipOption.allCases, id: \.self) { chip in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedChip = chip
                                    }
                                } label: {
                                    Text(chip.rawValue)
                                        .font(NimvaFont.sectionLabel)
                                        .foregroundStyle(selectedChip == chip ? .white : chip.color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedChip == chip ? chip.color : chip.color.opacity(0.12))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(chip.color.opacity(selectedChip == chip ? 0 : 0.4), lineWidth: 1))
                                }
                                .frame(minHeight: 44)
                            }
                        }

                        Text("Use \"No energy\" for holidays, rest days, or reminders that don't actually cost you anything.")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted.opacity(0.7))
                            .multilineTextAlignment(.leading)

                        if selectedChip != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NimvaColors.teal)
                                    .font(NimvaFont.body)
                                Text("Nimva learns from taps like this over time")
                                    .font(NimvaFont.micro)
                                    .foregroundStyle(NimvaColors.teal)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(16)
                    .background(NimvaColors.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("You can always update energy labels later — and Nimva gets better the more you use it.")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            Button(action: onNext) {
                Text("Got it")
                    .font(NimvaFont.button)
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

// MARK: - Screen 4: Energy anchor
// Asks the user for a personal example of a "Pretty Draining" event.
// Stored in AppStorage and surfaced as a hint in AddEventView/EditEventView.

private struct EnergyAnchorScreen: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @State private var draft = ""
    @State private var showingCustomField = false
    @FocusState private var isFocused: Bool

    // Tap-first, matching screen 3's interaction pattern instead of breaking it — recognizing
    // an example is much lower-friction than generating an answer from a blank field,
    // especially for a slightly personal question this early, before any trust is built.
    // "Something else" keeps full autonomy for anyone these don't fit.
    private let presets = ["Back-to-back classes", "A tough workout", "Long meetings", "Social events"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        EmberView(expression: .calm, size: .big)
                            .frame(width: 88, height: 88)
                            .padding(.top, 100)

                        Text("What drains you most?")
                            .font(NimvaFont.greeting)
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Nimva uses your answer to make \"Pretty Draining\" feel personal — not just abstract.")
                            .font(NimvaFont.body)
                            .foregroundStyle(NimvaColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Think of one thing that leaves you spent. What is it?")
                            .font(NimvaFont.bodyMedium)
                            .foregroundStyle(NimvaColors.textSecondary)

                        VStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                let isSelected = draft == preset && !showingCustomField
                                Button {
                                    draft = preset
                                    showingCustomField = false
                                    isFocused = false
                                } label: {
                                    Text(preset)
                                        .font(NimvaFont.sectionLabel)
                                        .foregroundStyle(isSelected ? .white : NimvaColors.teal)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isSelected ? NimvaColors.teal : NimvaColors.teal.opacity(0.12))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(NimvaColors.teal.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
                                }
                                .frame(minHeight: 44)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }

                            Button {
                                showingCustomField = true
                                draft = ""
                                isFocused = true
                            } label: {
                                Text("Something else…")
                                    .font(NimvaFont.sectionLabel)
                                    .foregroundStyle(showingCustomField ? .white : NimvaColors.textMuted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(showingCustomField ? NimvaColors.purplePrimary : NimvaColors.surfaceDeep)
                                    .clipShape(Capsule())
                            }
                            .frame(minHeight: 44)
                            .accessibilityAddTraits(showingCustomField ? .isSelected : [])
                        }

                        if showingCustomField {
                            TextField("Type your own…", text: $draft)
                                .font(.system(.subheadline))
                                .foregroundStyle(NimvaColors.textPrimary)
                                .padding(14)
                                .background(NimvaColors.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .focused($isFocused)
                                .onSubmit { saveAndContinue() }
                        }

                        // Live preview — shows the actual payoff now, instead of only promising
                        // it for a later screen the user may not connect this moment to.
                        if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(NimvaFont.micro)
                                Text("Like: \"\(draft)\"")
                                    .font(NimvaFont.micro)
                            }
                            .foregroundStyle(NimvaColors.teal)
                            .transition(.opacity)
                        }
                    }
                    .nimvaAnimation(NimvaAnimation.stateChange, value: showingCustomField)

                    Text("This appears as a hint under \"Pretty Draining\" when you add events. You can change it in Settings anytime.")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }

            VStack(spacing: 12) {
                Button(action: saveAndContinue) {
                    Text("Save and continue")
                        .font(NimvaFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NimvaColors.purplePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(NimvaFont.callout)
                        .foregroundStyle(NimvaColors.textMuted)
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    private func saveAndContinue() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { energyAnchorLabel = trimmed }
        onNext()
    }
}

// MARK: - Screen 5: Ready

private struct ReadyScreen: View {
    let onAddEvent: () -> Void
    let onSkip: () -> Void

    @AppStorage("displayName") private var displayName = ""
    @State private var nameInput = ""
    @State private var showAddEvent = false
    @FocusState private var nameFocused: Bool

    // Calendar import — a friction reducer for Step 1 specifically, since this app's
    // core audience (students) usually already has classes/meetings in their phone
    // calendar. Kept secondary to manual entry and asked for right where the benefit
    // is obvious (not cold on screen 1) — matches how EventKit permission priming
    // works best: request access when the reason is immediate and visible.
    @Environment(\.modelContext) private var modelContext
    @Query private var existingEvents: [Event]
    @State private var ekStore = EKEventStore()
    @State private var isImportingFromCalendar = false
    @State private var showingCalendarImport = false
    @State private var showingCalendarDenied = false
    @State private var calendarCandidates: [CalendarImportService.ImportCandidate] = []

    // Tracks whether the AddEventView sheet actually resulted in a saved event, vs. being
    // cancelled — the two need different outcomes (see the sheet's onDismiss below).
    @State private var eventCountBeforeSheet = 0
    @State private var justAddedEventName: String? = nil

    private let steps = [
        ("1", "Add your fixed events", "Classes, meetings — or import them from your calendar"),
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
                            .font(NimvaFont.display)
                            .foregroundStyle(NimvaColors.textPrimary)

                        Text("Here's how to get your first week built:")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.textSecondary)
                    }

                    // Name input — sets the AppStorage key HomeView uses for the greeting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should Nimva call you?")
                            .font(NimvaFont.bodyMedium)
                            .foregroundStyle(NimvaColors.textSecondary)
                        TextField("Your name (optional)", text: $nameInput)
                            .font(.system(.subheadline))
                            .foregroundStyle(NimvaColors.textPrimary)
                            .padding(14)
                            .background(NimvaColors.cardDark)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($nameFocused)
                            .onSubmit { saveName() }
                    }

                    // Step checklist
                    VStack(spacing: 10) {
                        ForEach(steps, id: \.0) { number, title, subtitle in
                            HStack(spacing: 14) {
                                Text(number)
                                    .font(NimvaFont.bodyBold)
                                    .foregroundStyle(NimvaColors.purplePrimary)
                                    .frame(width: 28, height: 28)
                                    .background(NimvaColors.purplePrimary.opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(NimvaFont.bodySemi)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text(subtitle)
                                        .font(NimvaFont.micro)
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
                if let eventName = justAddedEventName {
                    // A real event was actually saved — quiet, honest confirmation using
                    // their own data, not a generic illustration. No new screen, no extra
                    // required step; "Let's go" reuses onSkip since its job (proceed without
                    // forcing the add-event sheet open again on Home) is exactly right here.
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(NimvaFont.body)
                        Text("\"\(eventName)\" is on your week.")
                            .font(NimvaFont.body)
                    }
                    .foregroundStyle(NimvaColors.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    .transition(.opacity)

                    Button {
                        saveName()
                        onSkip()
                    } label: {
                        Text("Let's go")
                            .font(NimvaFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(NimvaColors.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    Button {
                        saveName()
                        eventCountBeforeSheet = existingEvents.count
                        showAddEvent = true
                    } label: {
                        Text("Add my first event")
                            .font(NimvaFont.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(NimvaColors.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        saveName()
                        connectAndImportCalendar()
                    } label: {
                        if isImportingFromCalendar {
                            ProgressView()
                                .tint(NimvaColors.textSecondary)
                        } else {
                            Text("or, add from calendar")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textSecondary)
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(isImportingFromCalendar)

                    Button {
                        saveName()
                        onSkip()
                    } label: {
                        Text("Maybe later")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    .frame(minHeight: 44)
                }
            }
            .nimvaAnimation(NimvaAnimation.stateChange, value: justAddedEventName)
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
        // Presenting AddEventView here so the user can add their first event before being
        // dropped into the main app. onDismiss only calls onAddEvent (which flags Home to
        // auto-open the add sheet again) when the sheet was cancelled without saving — a
        // real save here shouldn't immediately trigger a second add-event prompt on launch.
        .sheet(isPresented: $showAddEvent, onDismiss: {
            if existingEvents.count > eventCountBeforeSheet {
                justAddedEventName = existingEvents
                    .sorted(by: { $0.createdAt > $1.createdAt })
                    .first?.name
            } else {
                onAddEvent()
            }
        }) {
            AddEventView()
        }
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView(
                candidates: calendarCandidates,
                onImport: { selected in
                    CalendarImportService.insert(selected, into: modelContext)
                    showingCalendarImport = false
                    // Events already exist now — no need to force-open the manual
                    // add-event sheet on first launch, unlike the "Add my first
                    // event" path. onSkip just proceeds to the trial prompt/completion.
                    onSkip()
                },
                onCancel: { showingCalendarImport = false }
            )
        }
        .alert("Calendar Access Needed", isPresented: $showingCalendarDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Nimva needs calendar access to import your events. Enable it in Settings › Privacy › Calendars, or add events manually instead.")
        }
    }

    private func connectAndImportCalendar() {
        isImportingFromCalendar = true
        Task {
            let granted = await CalendarImportService.requestAccess(store: ekStore)
            await MainActor.run {
                isImportingFromCalendar = false
                guard granted else {
                    showingCalendarDenied = true
                    return
                }
                calendarCandidates = CalendarImportService.fetchCandidates(
                    store: ekStore,
                    existingEvents: existingEvents
                )
                showingCalendarImport = true
            }
        }
    }

    private func saveName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            displayName = trimmed
        }
    }
}

#Preview {
    OnboardingView()
}
