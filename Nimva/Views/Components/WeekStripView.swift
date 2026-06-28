import SwiftUI

// Horizontal 7-day strip. The selected day scales up; a warm spark dot sits beneath it.
// dailyLoads drives the colored dot per day (green / amber / blue based on load level).
struct WeekStripView: View {
    @Binding var selectedDay: DayOfWeek
    let dailyLoads: [DayOfWeek: Double]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                DayColumn(
                    day: day,
                    load: dailyLoads[day] ?? 0,
                    isSelected: day == selectedDay
                )
                .onTapGesture {
                    NimvaHaptics.selection()
                    selectedDay = day
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - DayColumn

private struct DayColumn: View {
    let day: DayOfWeek
    let load: Double
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            // 3-letter day abbreviation
            Text(day.shortName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? NimvaColors.textPrimary : NimvaColors.textMuted)

            // Load dot: green = light, amber = moderate, blue = heavy
            Circle()
                .fill(loadColor)
                .frame(width: 6, height: 6)

            // Spark — warm glowing dot marking the selected day.
            // Hidden (opacity 0) for non-selected days so layout stays stable.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "ffd9a0"), NimvaColors.amberWarm]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: NimvaColors.amberWarm.opacity(0.9), radius: 6, x: 0, y: 0)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .nimvaAnimation(NimvaAnimation.stateChange, value: isSelected)
    }

    private var loadColor: Color {
        switch load {
        case ..<1.0: return NimvaColors.teal       // light
        case ..<2.0: return NimvaColors.amber      // moderate
        default:     return NimvaColors.heavyBlue  // heavy
        }
    }
}

#Preview {
    WeekStripView(
        selectedDay: .constant(.wednesday),
        dailyLoads: [
            .monday: 0.5, .tuesday: 1.2, .wednesday: 2.5,
            .thursday: 0.8, .friday: 1.7, .saturday: 0.0, .sunday: 0.3
        ]
    )
    .padding()
    .background(NimvaColors.background)
}
