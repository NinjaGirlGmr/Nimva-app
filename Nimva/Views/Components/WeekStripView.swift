import SwiftUI

// Horizontal 7-day strip. The selected day scales up; a warm spark dot sits beneath it.
// dailyLoads drives the colored dot per day (green / amber / blue based on load level).
struct WeekStripView: View {
    @Binding var selectedDay: DayOfWeek
    let dailyLoads: [DayOfWeek: Double]
    let today: DayOfWeek

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DayOfWeek.orderedForLocale, id: \.self) { day in
                DayColumn(
                    day: day,
                    load: dailyLoads[day] ?? 0,
                    isSelected: day == selectedDay,
                    isToday: day == today
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
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            // 3-letter day abbreviation — teal when today, bright when selected
            Text(day.shortName.uppercased())
                .font(.system(size: 10, weight: isToday ? .semibold : .medium))
                .foregroundStyle(isSelected ? NimvaColors.textPrimary : isToday ? NimvaColors.teal : NimvaColors.textMuted)

            // Load dot: hidden when empty, scales up and glows on heavy days
            ZStack {
                Circle()
                    .fill(loadColor)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: load >= 2.0 ? NimvaColors.heavyBlue.opacity(0.6) : .clear,
                            radius: 5, x: 0, y: 0)
                    .opacity(load == 0 ? 0 : 1)
            }
            .frame(width: 9, height: 9)

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
        .nimvaAnimation(NimvaAnimation.buttonPress, value: isSelected)
    }

    private var dotSize: CGFloat {
        switch load {
        case 0:      return 5
        case ..<1.0: return 5
        case ..<2.0: return 7
        default:     return 9
        }
    }

    private var loadColor: Color {
        switch load {
        case ..<1.0: return NimvaColors.teal
        case ..<2.0: return NimvaColors.amber
        default:     return NimvaColors.heavyBlue
        }
    }
}

#Preview {
    WeekStripView(
        selectedDay: .constant(.wednesday),
        dailyLoads: [:],
        today: .wednesday
    )
    WeekStripView(
        selectedDay: .constant(.wednesday),
        dailyLoads: [
            .monday: 0.5, .tuesday: 1.2, .wednesday: 2.5,
            .thursday: 0.8, .friday: 1.7, .saturday: 0.0, .sunday: 0.3
        ],
        today: .monday
    )
    .padding()
    .background(NimvaColors.background)
}
