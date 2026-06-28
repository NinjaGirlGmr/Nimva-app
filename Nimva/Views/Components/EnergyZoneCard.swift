import SwiftUI

// The energy zone card: Ember avatar + mood/note + weekly bar (top half),
// then three stat chips (bottom half). All data is derived from the live schedule.
struct EnergyZoneCard: View {
    let selectedDay: DayOfWeek
    let dailyLoads: [DayOfWeek: Double]
    let heavyDays: Set<DayOfWeek>
    let eventsOnSelectedDay: Int
    let overflowCount: Int     // flexible events that couldn't be placed
    let userType: UserType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedLoad: Double { dailyLoads[selectedDay] ?? 0 }
    private var isHeavy: Bool { heavyDays.contains(selectedDay) }
    // True when today is lighter but tomorrow is a heavy day — triggers a forward warning.
    private var tomorrowIsHeavy: Bool {
        guard let nextDay = selectedDay.next else { return false }
        return !isHeavy && heavyDays.contains(nextDay)
    }

    // Ember's glow ring shifts warm (amber) for heavy days, cool (teal) for light
    private var emberRingColor: Color { isHeavy ? NimvaColors.amberWarm : NimvaColors.teal }

    // Weekly energy level: sum of all loads / (7 days × heavy threshold)
    private var weeklyPercent: Double {
        let total = dailyLoads.values.reduce(0, +)
        let capacity = Double(DayOfWeek.allCases.count) * Scheduler.heavyDayThreshold
        return min(total / capacity, 1.0)
    }

    private var heaviestDayName: String {
        dailyLoads.max(by: { $0.value < $1.value })?.key.shortName ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top row: Ember + mood text + energy bar ──
            HStack(alignment: .top, spacing: 14) {
                EmberAvatar(ringColor: emberRingColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(moodLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NimvaColors.textPrimary)
                        .contentTransition(.opacity)

                    Text(dayNote)
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)

                    Spacer(minLength: 8)

                    WeeklyEnergyBar(percent: weeklyPercent)
                }
                .animation(reduceMotion ? .none : NimvaAnimation.stateChange, value: selectedDay)
            }
            .padding(16)

            Rectangle()
                .fill(NimvaColors.border)
                .frame(height: 1)

            // ── Bottom row: 3 stat chips ──
            HStack(spacing: 8) {
                StatChip(value: "\(eventsOnSelectedDay)", label: "events today")
                StatChip(value: heaviestDayName,          label: "heaviest day")
                StatChip(value: "\(overflowCount)",        label: "flex unplaced")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(reduceMotion ? .none : NimvaAnimation.stateChange, value: selectedDay)
        }
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var moodLabel: String {
        // Label reflects today's load level; the phrasing shifts based on user type.
        switch userType {
        case .optimizer:
            switch selectedLoad {
            case ..<0.5: return "Feeling light"
            case ..<1.0: return "Looking steady"
            case ..<2.0: return "Getting there"
            default:     return "Heads up"
            }
        case .overloadedFixed:
            switch selectedLoad {
            case ..<0.5: return "Clear window"
            case ..<1.0: return "Some breathing room"
            case ..<2.0: return "Packed day"
            default:     return "Heavy load"
            }
        case .patternLearner:
            switch selectedLoad {
            case ..<0.5: return "Lighter day"
            case ..<1.0: return "Looking manageable"
            case ..<2.0: return "Busy day"
            default:     return "Heads up"
            }
        }
    }

    private var dayNote: String {
        // Forward warning takes priority when tomorrow is the heavy day.
        if tomorrowIsHeavy {
            switch userType {
            case .optimizer:      return "Tomorrow's your heaviest day — take it easy tonight"
            case .overloadedFixed: return "Tomorrow looks heavy — how you spend today matters"
            case .patternLearner: return "Heavy day ahead — a good night to wind down early"
            }
        }

        // Otherwise show a note about today's load, framed for the user type.
        switch userType {
        case .optimizer:
            switch selectedLoad {
            case ..<0.5: return "Easy \(selectedDay.displayName) — a good time to rest"
            case ..<1.0: return "Manageable day — you've got this"
            case ..<2.0: return "Moderate load — pace yourself today"
            default:     return "Heavy \(selectedDay.displayName) — take it one thing at a time"
            }
        case .overloadedFixed:
            switch selectedLoad {
            case ..<0.5: return "No big events on \(selectedDay.displayName) — this is your recovery time"
            case ..<1.0: return "Lighter load here — protect this time if you can"
            case ..<2.0: return "Back-to-back today — the load is real, not just in your head"
            default:     return "A lot on \(selectedDay.displayName) — Nimva can't move these, but naming it helps"
            }
        case .patternLearner:
            switch selectedLoad {
            case ..<0.5: return "Less on \(selectedDay.displayName) — good time for lower-energy work"
            case ..<1.0: return "Moderate day — your patterns are shaping how I schedule around this"
            case ..<2.0: return "Heavier load today — I've been routing easier tasks around this"
            default:     return "Heavy \(selectedDay.displayName) — I'll keep flex tasks lighter around this"
            }
        }
    }
}

// MARK: - Ember Avatar

// Placeholder circle for Ember until character art is ready.
// The warm glow radiates from the center, making Ember the light source of the card.
private struct EmberAvatar: View {
    let ringColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPulsing = false

    var body: some View {
        ZStack {
            // Soft radial glow — breathes slowly to feel alive, skipped if reduce motion is on
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            NimvaColors.amberWarm.opacity(0.32),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 32
                    )
                )
                .frame(width: 64, height: 64)
                .blur(radius: 4)
                .scaleEffect(glowPulsing ? 1.1 : 1.0)
                .opacity(glowPulsing ? 0.44 : 0.32)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: glowPulsing
                )
                .onAppear { glowPulsing = true }

            // Avatar circle — ring color shifts warm/cool based on day load
            Circle()
                .fill(NimvaColors.surfaceDeep)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 2)
                )

            // Placeholder emoji — replaced by custom Ember art in production
            Text("🐣")
                .font(.system(size: 22))
        }
        .frame(width: 56, height: 56)
        .nimvaAnimation(NimvaAnimation.stateChange, value: ringColor)
    }
}

// MARK: - Weekly Energy Bar

private struct WeeklyEnergyBar: View {
    let percent: Double  // 0.0–1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Weekly energy")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .textCase(.uppercase)
                .kerning(0.6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NimvaColors.purpleMuted)
                        .frame(height: 6)

                    // Fill — gradient teal → mauve → amber per design spec
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    NimvaColors.teal,
                                    Color(hex: "a8689c"),  // mauve
                                    NimvaColors.amberWarm
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * percent, height: 6)
                        .nimvaAnimation(NimvaAnimation.valueUpdate, value: percent)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NimvaColors.textPrimary)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .textCase(.uppercase)
                .kerning(0.4)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(NimvaColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VStack(spacing: 16) {
        EnergyZoneCard(
            selectedDay: .tuesday,
            dailyLoads: [.monday: 0.5, .tuesday: 0.8, .wednesday: 2.5,
                         .thursday: 0.8, .friday: 1.7, .saturday: 0.0, .sunday: 0.3],
            heavyDays: [.wednesday, .friday],
            eventsOnSelectedDay: 2,
            overflowCount: 0,
            userType: .optimizer   // Tuesday isn't heavy but Wednesday is → forward warning
        )
        EnergyZoneCard(
            selectedDay: .wednesday,
            dailyLoads: [.monday: 0.5, .tuesday: 1.2, .wednesday: 2.5,
                         .thursday: 0.8, .friday: 1.7, .saturday: 0.0, .sunday: 0.3],
            heavyDays: [.wednesday, .friday],
            eventsOnSelectedDay: 5,
            overflowCount: 0,
            userType: .overloadedFixed
        )
    }
    .padding()
    .background(NimvaColors.background)
}
