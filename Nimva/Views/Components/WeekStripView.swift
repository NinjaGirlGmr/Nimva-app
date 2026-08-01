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

    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"

    var body: some View {
        VStack(spacing: 6) {
            // 3-letter day abbreviation — teal when today, bright when selected
            Text(day.shortName.uppercased())
                .font(NimvaFont.chip)
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
            .accessibilityHidden(true)

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
                .accessibilityHidden(true)

            // Today anchor — persistent teal pip visible regardless of which day is selected,
            // so the user always knows where "now" is even when browsing other days.
            Circle()
                .fill(NimvaColors.teal)
                .frame(width: 4, height: 4)
                .opacity(isToday ? 1 : 0)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .nimvaAnimation(NimvaAnimation.buttonPress, value: isSelected)
        .accessibilityLabel(columnAccessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "" : "Switch to \(day.displayName)")
    }

    private var columnAccessibilityLabel: String {
        var parts: [String] = [day.displayName]
        if isToday { parts.append("today") }
        if load == 0 {
            parts.append("no events")
        } else if load < 1.0 {
            parts.append("light load")
        } else if load < 2.0 {
            parts.append("moderate load")
        } else {
            parts.append("heavy load")
        }
        return parts.joined(separator: ", ")
    }

    private var dotSize: CGFloat {
        switch LoadSeverity.forLoad(load) {
        case .light:    return 5
        case .moderate: return 7
        case .heavy:    return 9
        }
    }

    // Reads the same user-customizable Energy Colours as the day-load bar and Insights,
    // instead of the fixed brand tokens this used to use — previously a colorblind user who
    // customized their palette in Settings would find it respected everywhere except here,
    // the most prominent always-visible load indicator in the app.
    private var loadColor: Color {
        Color(hex: LoadSeverity.forLoad(load).hex(light: energyLightHex, mixed: energyMixedHex, heavy: energyHeavyHex))
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
