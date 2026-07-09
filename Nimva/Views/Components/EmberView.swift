import SwiftUI

enum EmberEmoteAnimation {
    case floatUp    // glitter stars — rise and fade
    case spin       // flame ring — rotates continuously
    case sinkDown   // exhaustion lines — drift downward and fade
}

enum EmberExpression: String, CaseIterable {
    case calm
    case happy
    case thinking
    case concerned
    case exhausted

    var faceImageName: String { "ember_face_\(rawValue)" }

    var placeholderText: String { "?" }

    var emoteName: String? {
        switch self {
        case .happy:     return "ember_emote_happy"
        case .thinking:  return "ember_emote_thinking"
        case .exhausted: return "ember_emote_exhausted"
        default:         return nil
        }
    }

    var emoteAnimation: EmberEmoteAnimation? {
        switch self {
        case .happy:     return .floatUp
        case .thinking:  return .spin
        case .exhausted: return .sinkDown
        default:         return nil
        }
    }

    var glowColor: Color {
        switch self {
        case .calm:      return NimvaColors.teal
        case .happy:     return NimvaColors.purplePrimary
        case .thinking:  return NimvaColors.amber
        case .concerned: return NimvaColors.coral
        case .exhausted: return NimvaColors.coral
        }
    }
}

enum EmberSize {
    case mini        // 24pt
    case standard    // 64pt
    case big         // 88pt

    var emojiFontSize: CGFloat {
        switch self {
        case .mini:     return 16
        case .standard: return 38
        case .big:      return 46
        }
    }

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

    // How far above center the spin emote sits
    var spinEmoteOffset: CGFloat {
        switch self {
        case .mini:     return -12
        case .standard: return -22
        case .big:      return -30
        }
    }
}

// Pivot points are UnitPoint(x:y:) within the full canvas frame.
// Tweak if the rotation pivot looks off — estimates based on where each frill's stem meets the head.
private struct FrillConfig {
    let name: String
    let anchor: UnitPoint
    let phase: Double   // animation delay in seconds, staggers each frill
    let amplitude: Double  // rotation degrees
}

private let frills: [FrillConfig] = [
    FrillConfig(name: "ember_frill_right_upper",  anchor: UnitPoint(x: 0.43, y: 0.45), phase: 0.00, amplitude: 5.0),
    FrillConfig(name: "ember_frill_right_middle", anchor: UnitPoint(x: 0.45, y: 0.46), phase: 0.25, amplitude: 5.0),
    FrillConfig(name: "ember_frill_right_lower",  anchor: UnitPoint(x: 0.31, y: 0.61), phase: 0.50, amplitude: 5.0),
    FrillConfig(name: "ember_frill_left_upper",   anchor: UnitPoint(x: 0.54, y: 0.46), phase: 0.15, amplitude: 5.0),
    FrillConfig(name: "ember_frill_left_middle",  anchor: UnitPoint(x: 0.50, y: 0.57), phase: 0.38, amplitude: 5.0),
    FrillConfig(name: "ember_frill_left_lower",   anchor: UnitPoint(x: 0.52, y: 0.60), phase: 0.60, amplitude: 5.0),
]

struct EmberView: View {
    var expression: EmberExpression = .calm
    var size: EmberSize = .standard

    @State private var breathing = false
    @State private var frillWave = false
    @State private var displayed: EmberExpression = .calm
    @State private var emoteFloat = false      // drives float/sink offset + opacity
    @State private var emoteRotation: Double = 0  // drives spin

    var body: some View {
        ZStack {
            if size != .mini {
                Circle()
                    .fill(displayed.glowColor)
                    .blur(radius: 28)
                    .opacity(0.22)
                    .scaleEffect(1.35)
                    .animation(.easeInOut(duration: 0.5), value: displayed)
            }

            ZStack {
                ForEach(frills, id: \.name) { frill in
                    frillLayer(frill)
                }

                if UIImage(named: "ember_head") != nil {
                    Image("ember_head")
                        .resizable()
                        .scaledToFit()
                }

                faceLayer(for: displayed)
                    .id(displayed)
                    .transition(.opacity)

                // Emote overlay — shown at all sizes; glow is still suppressed at mini
                // to avoid bleeding into surrounding card backgrounds
                emoteLayer(for: displayed)
                    .id("emote_\(displayed.rawValue)")
                    .transition(.opacity)
            }
            .scaleEffect(breathing ? size.breathScale : 1.0)
            .offset(y: breathing ? -size.breathLift : 0)
        }
        .onAppear {
            displayed = expression
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                frillWave = true
            }
            startEmoteAnimation(for: expression)
        }
        .onChange(of: expression) { _, newExpression in
            withAnimation(.easeInOut(duration: 0.35)) {
                displayed = newExpression
            }
            emoteFloat = false
            emoteRotation = 0
            startEmoteAnimation(for: newExpression)
        }
    }

    private func startEmoteAnimation(for exp: EmberExpression) {
        guard let anim = exp.emoteAnimation else { return }
        switch anim {
        case .floatUp, .sinkDown:
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                emoteFloat = true
            }
        case .spin:
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                emoteRotation = -360
            }
        }
    }

    @ViewBuilder
    private func frillLayer(_ config: FrillConfig) -> some View {
        if UIImage(named: config.name) != nil {
            Image(config.name)
                .resizable()
                .scaledToFit()
                .rotationEffect(
                    .degrees(frillWave ? config.amplitude : -config.amplitude),
                    anchor: config.anchor
                )
                .animation(
                    .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true)
                    .delay(config.phase),
                    value: frillWave
                )
        }
    }

    @ViewBuilder
    private func faceLayer(for exp: EmberExpression) -> some View {
        if UIImage(named: exp.faceImageName) != nil {
            Image(exp.faceImageName)
                .resizable()
                .scaledToFit()
        } else {
            Text(exp.placeholderText)
                .font(.system(size: size.emojiFontSize, weight: .bold))
                .foregroundStyle(NimvaColors.textMuted)
        }
    }

    @ViewBuilder
    private func emoteLayer(for exp: EmberExpression) -> some View {
        if let name = exp.emoteName, let anim = exp.emoteAnimation,
           UIImage(named: name) != nil {
            switch anim {
            case .floatUp:
                // Glitter stars: gentle rise and soft fade
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .opacity(emoteFloat ? 0 : 0.85)
                    .offset(y: emoteFloat ? -14 : 0)

            case .sinkDown:
                // Exhaustion lines: drift downward and fade
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .opacity(emoteFloat ? 0.0 : 0.85)
                    .offset(y: emoteFloat ? 20 : 0)

            case .spin:
                // Flame ring: continuous rotation above the head
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(emoteRotation))
                    .offset(y: size.spinEmoteOffset)
            }
        }
    }
}

#Preview {
    ZStack {
        NimvaColors.background.ignoresSafeArea()
        VStack(spacing: 32) {
            ForEach([("88pt", 88.0), ("64pt", 64.0), ("24pt", 24.0)], id: \.0) { label, pts in
                HStack(spacing: 16) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textMuted)
                        .frame(width: 40, alignment: .leading)
                    ForEach(EmberExpression.allCases, id: \.self) { exp in
                        EmberView(expression: exp, size: pts == 24 ? .mini : pts == 88 ? .big : .standard)
                            .frame(width: pts, height: pts)
                    }
                }
            }
        }
        .padding()
    }
}
