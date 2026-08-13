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
    // Optional so the Plan tab's read-only day-detail view (which never wires this up)
    // stays exactly as it is today. Where it IS wired up (Home), it's a second path to the
    // same delete flow the long-press context menu already offers — visible and reachable
    // with a plain tap, not something that requires discovering or holding a gesture.
    var onDelete: (() -> Void)? = nil

    private var isCompleted: Bool { completionState == .completed }

    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var visible = false

    // Badges sit trailing next to the name in a single row when there are few enough of
    // them to fit comfortably. Once the "more options" menu was added alongside the energy
    // badge, type tag, and checkmark, Home's interactive cards sit at 4 badges as their
    // *normal* count (5 when the Now/Next pill is also showing) — squeezing that many chips
    // plus a name into one trailing row was producing exactly what it looks like: badge
    // text getting compressed down to a couple of characters and wrapping vertically inside
    // its own capsule. So this isn't just an accessibility-size fallback anymore — 4+
    // badges moves to the stacked layout (name on top, badges in their own full-width row
    // below) regardless of text size, with a second-row fallback if even that doesn't fit
    // (see badgesRow/twoRowBadges). The read-only Plan tab day-detail view never has more
    // than 2 badges (no checkmark, no delete menu there), so it's unaffected either way.
    private var useStackedLayout: Bool {
        dynamicTypeSize >= .accessibility1 || badgeList.count >= 4
    }

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

                Group {
                    if useStackedLayout {
                        VStack(alignment: .leading, spacing: 8) {
                            nameAndSubtitleBlock
                            badgesRow
                        }
                    } else {
                        HStack(spacing: 8) {
                            nameAndSubtitleBlock
                            Spacer(minLength: 8)
                            badgesRow
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, useStackedLayout ? 14 : 6)
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

    @ViewBuilder
    private var nameAndSubtitleBlock: some View {
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
    }

    // Built as an array (not a plain @ViewBuilder HStack) so the accessibility-size path
    // below can split it across rows without needing to know in advance which optional
    // badges (Now/Next pill, checkmark) are actually present.
    private var badgeList: [AnyView] {
        var list: [AnyView] = []
        if let label = nextUpLabel {
            list.append(AnyView(nowNextPill(label)))
        }
        list.append(AnyView(energyBadge))
        list.append(AnyView(typeTag))
        if onCheckmark != nil {
            list.append(AnyView(checkmarkButton))
        }
        if onDelete != nil {
            list.append(AnyView(moreMenuButton))
        }
        return list
    }

    @ViewBuilder
    private var badgesRow: some View {
        if useStackedLayout {
            // Single row first (matches the normal layout's look); if the badges' own text
            // is too wide for that even on their own full-width row, ViewThatFits falls
            // back to two shorter rows instead of letting them overflow the card.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(badgeList.indices, id: \.self) { badgeList[$0] }
                }
                twoRowBadges
            }
        } else {
            HStack(spacing: 6) {
                ForEach(badgeList.indices, id: \.self) { badgeList[$0] }
            }
        }
    }

    private var twoRowBadges: some View {
        let mid = (badgeList.count + 1) / 2
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(badgeList.prefix(mid).indices, id: \.self) { badgeList[$0] }
            }
            if badgeList.count > mid {
                HStack(spacing: 6) {
                    ForEach(mid..<badgeList.count, id: \.self) { badgeList[$0] }
                }
            }
        }
    }

    // "Now" / "Next" pill — only on today's first uncompleted event.
    // lineLimit(1) + fixedSize on all three chip labels below: without them, a genuinely
    // tight row compresses the Text down to whatever sliver of width is left, which makes
    // it wrap into a couple of illegible vertical characters rather than staying one full
    // word — the exact bug that motivated useStackedLayout's badge-count threshold above.
    // Between the two, if a row is still too tight, it's the name/subtitle that wraps to a
    // second line instead — a badge shrinking to 2 illegible letters is worse than a name
    // taking an extra line, and useStackedLayout now keeps this from being needed often.
    private func nowNextPill(_ label: String) -> some View {
        Text(label)
            .font(NimvaFont.chip)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(NimvaColors.teal)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(NimvaColors.teal.opacity(0.12))
            .clipShape(Capsule())
    }

    private var energyBadge: some View {
        Text(energyLabel)
            .font(NimvaFont.chip)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(energyColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(energyColor.opacity(0.12))
            .clipShape(Capsule())
    }

    // "Must do" with amber tint for priority flex events
    private var typeTag: some View {
        Text(typeTagLabel)
            .font(NimvaFont.chip)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(typeTagColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(typeTagBackground)
            .clipShape(Capsule())
    }

    // Nested Button intercepts its own tap, outer Button handles edit. Cycles three states
    // (#83): not started → in progress → completed, so a half-finished task can be marked
    // "started" without an all-or-nothing call. Only shown when a checkmark action is
    // actually wired up (Home) — a read-only context (Plan tab day detail) passes
    // onCheckmark: nil and just hides it (badgeList never includes it in that case).
    private var checkmarkButton: some View {
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

    // A visible, plain-tap alternative to the long-press context menu Home also attaches
    // to this card — the exact "single tap, then choose" pattern used for the "+" button,
    // for the same reason: a sustained long-press is a real barrier for anyone with limited
    // motor control, and this way Edit/Delete don't require discovering or holding one.
    // Edit reuses onTap so there's one source of truth for what "edit this event" does.
    private var moreMenuButton: some View {
        Menu {
            Button {
                onTap?()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(.title3))
                .foregroundStyle(NimvaColors.textMuted)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))
        }
        .accessibilityLabel("More options")
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
        // Was NimvaColors.border — a near-invisible structural-divider color, nearly
        // identical to the card background it sits on. A tester reported not knowing this
        // button existed until they tapped it by accident. textMuted is the app's
        // established "visible but secondary" tone (5.04:1 contrast) — present without
        // looking like it's already been interacted with.
        case .notStarted: return NimvaColors.textMuted
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
