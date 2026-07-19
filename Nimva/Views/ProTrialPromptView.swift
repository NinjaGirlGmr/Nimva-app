import SwiftUI

// Shown once, after the final onboarding screen, before the user enters the app.
// Both buttons (accept and skip) lead to the same place — the main app.
// The only difference is whether a StoreKit purchase flow is attempted first.
// AppStorage key "hasSeenProTrialOffer" ensures this never appears twice.
struct ProTrialPromptView: View {
    @Environment(ProService.self) private var proService
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    emberHeader
                    bulletCard
                    finePrint
                    ctaButtons
                }
                .padding(.horizontal, 28)
                .padding(.top, 80)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: Sections

    private var emberHeader: some View {
        VStack(spacing: 14) {
            EmberView(expression: .happy, size: .big)
                .frame(width: 88, height: 88)

            Text("One more thing before you start")
                .font(NimvaFont.pageTitle)
                .foregroundStyle(NimvaColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Nimva PRO is free for 2 weeks")
                .font(NimvaFont.cardTitle)
                .foregroundStyle(NimvaColors.teal)
                .multilineTextAlignment(.center)
        }
    }

    private var bulletCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            bullet(
                icon: "chart.line.uptrend.xyaxis",
                color: NimvaColors.purplePrimary,
                title: "Energy trends over time",
                detail: "See which weeks keep feeling heavy — and why."
            )
            Divider().background(NimvaColors.border)
            bullet(
                icon: "text.bubble.fill",
                color: NimvaColors.teal,
                title: "Pattern coaching",
                detail: "Plain language explaining what's behind the pattern and what might help."
            )
            Divider().background(NimvaColors.border)
            bullet(
                icon: "bell.badge.fill",
                color: NimvaColors.amber,
                title: "Capacity alerts",
                detail: "Know your lighter windows before they pass — especially useful for ADHD."
            )
        }
        .padding(18)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }

    private var finePrint: some View {
        Text("No charge until after 14 days. Cancel anytime from Settings.")
            .font(NimvaFont.micro)
            .foregroundStyle(NimvaColors.textMuted)
            .multilineTextAlignment(.center)
    }

    private var ctaButtons: some View {
        VStack(spacing: 16) {
            // Primary — attempts the purchase, then continues regardless of result
            Button {
                Task {
                    // Purchase failure is non-fatal here — user enters the app either way
                    // and can retry from the Insights tab.
                    try? await proService.purchase()
                    onComplete()
                }
            } label: {
                Group {
                    if proService.purchaseInProgress {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start free trial")
                            .font(NimvaFont.button)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(NimvaColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(proService.purchaseInProgress)

            // Secondary — clearly visible, no guilt, no smaller text or hidden placement
            Button(action: onComplete) {
                Text("Maybe later — go to free version")
                    .font(NimvaFont.callout)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    // MARK: Helpers

    private func bullet(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(NimvaFont.callout)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NimvaFont.cardTitle)
                    .foregroundStyle(NimvaColors.textPrimary)
                Text(detail)
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ProTrialPromptView { }
        .environment(ProService())
}
