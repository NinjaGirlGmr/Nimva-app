import SwiftUI

// Shared event row — originally HomeView-only, extracted so the Plan tab's day-detail
// view (rolling calendar) can reuse the exact same rendering read-only, by simply
// omitting completionState/nextUpLabel/onCheckmark (all default to inert values).

struct EventCard: View {
    let event: Event
    var index: Int = 0
    var placementReason: String? = nil
    var completionState: SchedulerService.EventCompletionState = .notStarted
    var nextUpLabel: String? = nil
    var onTap: (() -> Void)? = nil
    var onCheckmark: (() -> Void)? = nil

    private var isCompleted: Bool { completionState == .completed }

    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 0) {
                // Left accent bar — purple for fixed, teal for flexible, a distinct violet
                // for a logged (retroactive) entry. Never color-only, though — the symbol
                // next to the name is the reliable signal, since this color could still
                // resemble someone's chosen severity palette in a way purple/teal don't.
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.wasLogged ? NimvaColors.logged : (event.isFixed ? NimvaColors.purplePrimary : NimvaColors.teal))
                    .frame(width: 3)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            if event.wasLogged {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(NimvaColors.logged)
                                    .accessibilityHidden(true)
                            }
                            Text(event.name)
                                .font(NimvaFont.bodyMedium)
                                .foregroundStyle(isCompleted ? NimvaColors.textMuted : NimvaColors.textPrimary)
                                .strikethrough(isCompleted, color: NimvaColors.textMuted)
                        }
                        Text(subtitleText)
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textSecondary)
                        if let reason = placementReason, !event.isFixed {
                            Text(reason)
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)
                        }
                    }

                    Spacer()

                    // "Now" / "Next" pill — only on today's first uncompleted event
                    if let label = nextUpLabel {
                        Text(label)
                            .font(NimvaFont.chip)
                            .foregroundStyle(NimvaColors.teal)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(NimvaColors.teal.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Energy badge
                    Text(energyLabel)
                        .font(NimvaFont.chip)
                        .foregroundStyle(energyColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(energyColor.opacity(0.12))
                        .clipShape(Capsule())

                    // Type tag — "Must do" with amber tint for priority flex events
                    Text(typeTagLabel)
                        .font(NimvaFont.chip)
                        .foregroundStyle(typeTagColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(typeTagBackground)
                        .clipShape(Capsule())

                    // Checkmark — nested Button intercepts its own tap, outer Button handles edit.
                    // Cycles three states (#83): not started → in progress → completed, so a
                    // half-finished task can be marked "started" without an all-or-nothing call.
                    // Only shown when a checkmark action is actually wired up (Home) — a read-only
                    // context (Plan tab day detail) passes onCheckmark: nil and just hides it.
                    if onCheckmark != nil {
                        Button {
                            onCheckmark?()
                        } label: {
                            Image(systemName: completionIconName)
                                .font(.system(.title3))
                                .foregroundStyle(completionIconColor)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(completionAccessibilityLabel)
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 6)
            }
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(EventCardStyle(reduceMotion: reduceMotion))
        // Only "completed" dims the card — "in progress" shouldn't read as a lesser state,
        // just a different one, per #83 (avoid all-or-nothing failure framing).
        .opacity(isCompleted ? 0.6 : 1.0)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Tap to edit")
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(NimvaAnimation.cardAppear.delay(Double(index) * 0.06)) {
                    visible = true
                }
            }
        }
    }

    private var cardAccessibilityLabel: String {
        let base = "\(event.name), \(typeTagLabel), \(energyLabel) energy, \(subtitleText)"
        switch completionState {
        case .completed:  return "Completed: \(base)"
        case .inProgress: return "In progress: \(base)"
        case .notStarted: return base
        }
    }

    private var completionIconName: String {
        switch completionState {
        case .completed:  return "checkmark.circle.fill"
        case .inProgress: return "circle.lefthalf.filled"
        case .notStarted: return "circle"
        }
    }

    private var completionIconColor: Color {
        switch completionState {
        case .completed:  return NimvaColors.teal
        case .inProgress: return NimvaColors.teal.opacity(0.6)
        case .notStarted: return NimvaColors.border
        }
    }

    private var completionAccessibilityLabel: String {
        switch completionState {
        case .completed:  return "Completed. Tap to reset."
        case .inProgress: return "In progress. Tap to mark complete."
        case .notStarted: return "Not started. Tap to mark in progress."
        }
    }

    private var typeTagLabel: String {
        if event.wasLogged { return "Logged" }
        if event.isFixed { return "Fixed" }
        return event.isPriority ? "Must do" : "Flex"
    }

    private var typeTagColor: Color {
        if event.wasLogged { return NimvaColors.logged }
        return !event.isFixed && event.isPriority ? NimvaColors.amber : NimvaColors.textMuted
    }

    private var typeTagBackground: Color {
        if event.wasLogged { return NimvaColors.logged.opacity(0.12) }
        return !event.isFixed && event.isPriority ? NimvaColors.amber.opacity(0.12) : NimvaColors.purpleMuted.opacity(0.5)
    }

    private var subtitleText: String {
        if event.isFixed {
            if let start = event.startTime, let end = event.endTime {
                let fmt = DateFormatter(); fmt.timeStyle = .short
                return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
            }
            return event.fixedDay?.displayName ?? ""
        } else {
            let window = event.preferredWindow?.displayName ?? "Any time"
            if let dur = event.duration {
                let mins = Int(dur / 60)
                let h = mins / 60; let m = mins % 60
                let s = h == 0 ? "\(m)m" : (m == 0 ? "\(h)h" : "\(h)h \(m)m")
                return "\(window) · \(s)"
            }
            return window
        }
    }

    private var energyLabel: String {
        EnergyLabel.allCases
            .min(by: { abs($0.cost - event.energyCost) < abs($1.cost - event.energyCost) })?
            .displayName ?? "–"
    }

    private var energyColor: Color {
        switch event.energyCost {
        case ..<0.35: return Color(hex: energyLightHex)
        case ..<0.6:  return Color(hex: energyMixedHex)
        default:      return Color(hex: energyHeavyHex)
        }
    }
}

// MARK: - EventCardStyle

// Replaces the external pressScale() modifier on EventCard.
// ButtonStyle.isPressed is the ScrollView-safe way to animate press state —
// DragGesture(minimumDistance: 0) inside simultaneousGesture can suppress
// tap recognition when nested inside a ScrollView.
struct EventCardStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1.0)
            .opacity(configuration.isPressed && !reduceMotion ? 0.85 : 1.0)
            .animation(NimvaAnimation.buttonPress, value: configuration.isPressed)
    }
}
