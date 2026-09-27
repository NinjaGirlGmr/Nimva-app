import SwiftUI

// The energy-level button row — previously three independent, near-identical copies
// (AddEventView, EditEventView, QuickAddEventsView), found while hardening this session's
// work. That drift already caused one real bug (QuickAddEventsView missing AddEventView's
// "never suggest for General" exclusion — fixed separately via PatternService.suggestedLabel).
// Extracting the UI itself closes the same kind of gap for anything visual, like this
// animation pass, which would otherwise need applying three times and could just as easily
// drift a fourth.
struct EnergyLabelPicker: View {
    @Binding var selectedLabel: EnergyLabel
    @Binding var energyCost: Double
    // Called after a label is tapped — e.g. flips energyManuallySet = true so a later
    // category change can't silently override an explicit choice. Omitted where that
    // concept doesn't apply (EditEventView writes straight to the live model).
    var onSelect: (() -> Void)? = nil
    // Settings' "Like: ___" anchor phrase, shown under Pretty Draining — omitted (default
    // "") wherever that context doesn't apply (QuickAddEventsView).
    var anchorLabel: String = ""

    var body: some View {
        VStack(spacing: 8) {
            ForEach(EnergyLabel.allCases, id: \.self) { label in
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        selectedLabel = label
                        energyCost = label.cost
                        onSelect?()
                    } label: {
                        Text(label.displayName)
                            .font(NimvaFont.calloutMed)
                            .foregroundStyle(selectedLabel == label ? .white : NimvaColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedLabel == label ? NimvaColors.purplePrimary : NimvaColors.surfaceDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedLabel == label ? NimvaColors.purplePrimary : NimvaColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .pressScale()
                    .frame(minHeight: 44)
                    .accessibilityAddTraits(selectedLabel == label ? .isSelected : [])

                    if label == .prettyDraining && !anchorLabel.isEmpty {
                        Text("Like: \(anchorLabel)")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .nimvaAnimation(NimvaAnimation.stateChange, value: selectedLabel)
    }
}
