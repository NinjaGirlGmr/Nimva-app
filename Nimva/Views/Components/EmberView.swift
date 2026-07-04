import SwiftUI

// Ember's four expression states. Each maps to a custom sprite image and an
// emoji fallback so the app runs normally while artwork is still being added.
enum EmberExpression: String, CaseIterable {
    case calm       // listening, waiting, manageable week
    case happy      // light/balanced week, celebrating
    case thinking   // generating schedule, working
    case concerned  // heavy week, rough check-in
    case exhausted  // genuinely unsustainable week

    var imageName: String { "ember_\(rawValue)" }

    var fallbackEmoji: String {
        switch self {
        case .calm:      return "😌"
        case .happy:     return "😊"
        case .thinking:  return "🤔"
        case .concerned: return "😮‍💨"
        case .exhausted: return "😔"
        }
    }
}

// The three sizes Ember appears at across the app.
enum EmberSize {
    case mini        // 24pt — passive indicator, week strip
    case standard    // 88pt — home screen card, check-in
    case big         // 64pt — done screens, onboarding moments

    var points: CGFloat {
        switch self {
        case .mini:     return 24
        case .standard: return 88
        case .big:      return 64
        }
    }

    // Emoji fallback font size that feels proportional at each size
    var emojiFontSize: CGFloat {
        switch self {
        case .mini:     return 16
        case .standard: return 38
        case .big:      return 46
        }
    }

    // Breathing amplitude scales down at smaller sizes so it doesn't look jittery
    var breathScale: CGFloat {
        switch self {
        case .mini:     return 1.015
        case .standard: return 1.025
        case .big:      return 1.03
        }
    }

    var breathLift: CGFloat {
        switch self {
        case .mini:     return 0.5
        case .standard: return 1.5
        case .big:      return 2.0
        }
    }
}

struct EmberView: View {
    var expression: EmberExpression = .calm
    var size: EmberSize = .standard

    @State private var breathing = false
    @State private var displayed: EmberExpression = .calm

    var body: some View {
        emberFace(for: displayed)
            .scaleEffect(breathing ? size.breathScale : 1.0)
            .offset(y: breathing ? -size.breathLift : 0)
            .onAppear {
                displayed = expression
                // Start the idle breathing loop
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    breathing = true
                }
            }
            .onChange(of: expression) { _, newExpression in
                // Crossfade to the new expression over 0.35s
                withAnimation(.easeInOut(duration: 0.35)) {
                    displayed = newExpression
                }
            }
    }

    // Uses the custom sprite if it exists in the asset catalog, otherwise
    // falls back to the emoji so every screen works before artwork is added.
    @ViewBuilder
    private func emberFace(for exp: EmberExpression) -> some View {
        if UIImage(named: exp.imageName) != nil {
            Image(exp.imageName)
                .resizable()
                .scaledToFit()
                .id(exp)
                .transition(.opacity)
        } else {
            Text(exp.fallbackEmoji)
                .font(.system(size: size.emojiFontSize))
                .id(exp)
                .transition(.opacity)
        }
    }
}

#Preview {
    ZStack {
        NimvaColors.background.ignoresSafeArea()
        VStack(spacing: 32) {
            ForEach([("56pt (current)", 56.0), ("72pt", 72.0), ("88pt", 88.0), ("104pt", 104.0)], id: \.0) { label, pts in
                HStack(spacing: 20) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textMuted)
                        .frame(width: 90, alignment: .leading)
                    EmberView(expression: .happy)
                        .frame(width: pts, height: pts)
                    EmberView(expression: .calm)
                        .frame(width: pts, height: pts)
                    EmberView(expression: .concerned)
                        .frame(width: pts, height: pts)
                    EmberView(expression: .exhausted)
                        .frame(width: pts, height: pts)
                }
            }
        }
        .padding()
    }
}
