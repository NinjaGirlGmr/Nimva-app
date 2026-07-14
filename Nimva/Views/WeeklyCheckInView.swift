import SwiftUI
import SwiftData

// 5-step conversational check-in. Ember speaks, user responds.
// Completed answers are persisted back to the WeekCache so Insights
// can compare predicted load against how the week actually felt.
struct WeeklyCheckInView: View {
    let cache: WeekCache
    let onDismiss: () -> Void

    @State private var step = 0
    @State private var overallRating: Double? = nil
    @State private var hardestDay: DayOfWeek? = nil
    @State private var noStandoutDay = false
    @State private var scheduleMatch: ScheduleMatch? = nil
    @State private var gotRest: RestLevel? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ScheduleMatch { case yes, mixed, no }
    private enum RestLevel    { case yes, little, no }

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if step > 0 && step < 5 {
                        Button {
                            NimvaHaptics.selection()
                            withAnimation(reduceMotion ? .none : NimvaAnimation.stateChange) { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(NimvaColors.textMuted)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Go back")
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    progressDots
                        .accessibilityHidden(true)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.top, 56)
                .padding(.horizontal, 16)

                Spacer()

                // id() forces SwiftUI to recreate the view on step change,
                // triggering the transition animation cleanly
                currentStep
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 40)),
                        removal:   .opacity.combined(with: .offset(x: -40))
                    ))
                    .padding(.horizontal, 28)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                if i == step {
                    Capsule()
                        .fill(NimvaColors.teal)
                        .frame(width: 22, height: 6)
                } else {
                    Circle()
                        .fill(i < step ? NimvaColors.teal : NimvaColors.purpleMuted)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .nimvaAnimation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
    }

    // MARK: Step router

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0: step1
        case 1: step2
        case 2: step3
        case 3: step4
        default: step5
        }
    }

    private func advance() {
        NimvaHaptics.selection()
        withAnimation(reduceMotion ? .none : NimvaAnimation.stateChange) { step += 1 }
    }

    // MARK: Step 1 — Overall energy

    private var step1: some View {
        VStack(spacing: 28) {
            emberSpeech(
                expression: .calm,
                text: "How did your energy hold up this week?"
            )

            VStack(spacing: 10) {
                energyChip("Felt great",      rating: 0.0,  color: NimvaColors.teal)
                energyChip("Pretty good",    rating: 0.33, color: Color(hex: "5b9e6a"))
                energyChip("Surviving",      rating: 0.67, color: NimvaColors.amber)
                energyChip("Pretty rough",   rating: 1.0,  color: NimvaColors.coral)
            }
        }
    }

    private func energyChip(_ label: String, rating: Double, color: Color) -> some View {
        Button {
            overallRating = rating
            // Brief delay so the selection highlight is visible before advancing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
        } label: {
            Text(label)
                .font(NimvaFont.cardTitle)
                .foregroundStyle(overallRating == rating ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(overallRating == rating ? color : color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: NimvaLayout.inputRadius)
                        .stroke(color.opacity(overallRating == rating ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityAddTraits(overallRating == rating ? .isSelected : [])
    }

    // MARK: Step 2 — Hardest day

    private var step2: some View {
        VStack(spacing: 28) {
            emberSpeech(
                expression: .thinking,
                text: "Which day hit hardest?"
            )

            VStack(spacing: 10) {
                // Two rows of days + full-width "no standout" at bottom
                // orderedForLocale respects US Sun–Sat vs ISO Mon–Sun
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(DayOfWeek.orderedForLocale, id: \.self) { day in
                        dayButton(day)
                    }
                }

                Button {
                    hardestDay = nil
                    noStandoutDay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
                } label: {
                    Text("No single standout")
                        .font(NimvaFont.cardTitle)
                        .foregroundStyle(noStandoutDay ? .white : NimvaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(noStandoutDay ? NimvaColors.purplePrimary : NimvaColors.purplePrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityAddTraits(noStandoutDay ? .isSelected : [])
            }
        }
    }

    private func dayButton(_ day: DayOfWeek) -> some View {
        let selected = hardestDay == day
        return Button {
            hardestDay = day
            noStandoutDay = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
        } label: {
            Text(day.shortName)
                .font(NimvaFont.cardTitle)
                .foregroundStyle(selected ? .white : NimvaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? NimvaColors.coral : NimvaColors.cardDark)
                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(day.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Step 3 — Schedule fit

    private var step3: some View {
        VStack(spacing: 28) {
            emberSpeech(
                expression: .calm,
                text: "Did the schedule feel manageable?"
            )

            VStack(spacing: 10) {
                matchChip("Yes, mostly",  match: .yes,   color: NimvaColors.teal)
                matchChip("Hit and miss", match: .mixed, color: NimvaColors.amber)
                matchChip("Not really",   match: .no,    color: NimvaColors.coral)
            }
        }
    }

    private func matchChip(_ label: String, match: ScheduleMatch, color: Color) -> some View {
        let selected = scheduleMatch == match
        return Button {
            scheduleMatch = match
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
        } label: {
            Text(label)
                .font(NimvaFont.cardTitle)
                .foregroundStyle(selected ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? color : color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: NimvaLayout.inputRadius)
                        .stroke(color.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Step 4 — Recovery

    private var step4: some View {
        VStack(spacing: 28) {
            emberSpeech(
                expression: .calm,
                text: "Did you get any real rest this week?"
            )

            VStack(spacing: 10) {
                restChip("Yes",       level: .yes,    color: NimvaColors.teal)
                restChip("A little",  level: .little, color: NimvaColors.amber)
                restChip("Not really",level: .no,     color: NimvaColors.coral)
            }
        }
    }

    private func restChip(_ label: String, level: RestLevel, color: Color) -> some View {
        let selected = gotRest == level
        return Button {
            gotRest = level
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
        } label: {
            Text(label)
                .font(NimvaFont.cardTitle)
                .foregroundStyle(selected ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? color : color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: NimvaLayout.inputRadius)
                        .stroke(color.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Step 5 — Done

    private var step5: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                EmberView(expression: closingExpression, size: .big)
                    .frame(width: 88, height: 88)

                Text(closingTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NimvaColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(closingMessage)
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let day = hardestDay {
                    Text("\(day.displayName) was the rough one — I'll keep that in mind when planning next week.")
                        .font(.system(size: 12))
                        .foregroundStyle(NimvaColors.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }

            Button {
                persistAndDismiss()
            } label: {
                Text("Back to home")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NimvaColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: Closing copy

    private var closingExpression: EmberExpression {
        guard let rating = overallRating else { return .happy }
        switch rating {
        case 0.0..<0.4: return .happy
        case 0.4..<0.7: return .calm
        default:        return .concerned
        }
    }

    // Headline varies by how the week actually felt — the ending should match the mood.
    private var closingTitle: String {
        switch overallRating ?? 0.5 {
        case ..<0.2: return "Strong week."
        case ..<0.5: return "Solid week."
        case ..<0.8: return "You got through it."
        default:     return "That was a tough one."
        }
    }

    // Generates a short, honest acknowledgment from the check-in answers.
    // Warm but not dismissive — the app should validate, not reassure.
    // Hardest day is handled by its own dedicated line in step5, not here.
    private var closingMessage: String {
        let rough  = (overallRating ?? 0) >= 0.67
        let noRest = gotRest == .no
        let badFit = scheduleMatch == .no

        if rough && noRest {
            return "A heavy week without much rest — that compounds. Let's make next week a bit lighter."
        } else if rough {
            return "That sounds genuinely hard. You don't have to pretend it wasn't."
        } else if noRest && badFit {
            return "The schedule didn't quite fit, and rest was hard to come by. That's real — not a failing on your part."
        } else if badFit {
            return "Sometimes the plan and the reality don't match. Nimva will get better at reading that over time."
        } else if (overallRating ?? 0) <= 0.25 {
            return "A good week. Those are worth noticing."
        } else {
            return "Thanks for checking in. Every week you track, Nimva understands you a little better."
        }
    }

    // MARK: Persistence

    private func persistAndDismiss() {
        cache.checkInRating = overallRating
        cache.checkInHardestDayRawValue = hardestDay?.rawValue
        cache.checkInCompletedAt = Date()
        onDismiss()
    }

    // MARK: Shared components

    private func emberSpeech(expression: EmberExpression, text: String) -> some View {
        VStack(spacing: 0) {
            EmberView(expression: expression, size: .big)
                .frame(width: 88, height: 88)

            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(NimvaColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
                .background(NimvaColors.cardDark)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 8)
        }
    }
}

// Preview omitted — WeeklyCheckInView requires a live WeekCache from SwiftData.
// Test via HomeView in the simulator: generate a week, then tap the check-in banner.
