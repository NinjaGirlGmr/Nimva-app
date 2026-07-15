import SwiftUI
import SwiftData
import Charts

// MARK: - InsightsView
// Routes to PRO content or the locked upgrade screen based on subscription status.
// The @Query lives inside InsightsProContent so SwiftData never fetches history
// for non-PRO users — no real data is computed or shown behind the lock.
struct InsightsView: View {
    @Environment(ProService.self) private var proService

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            if proService.isProEnabled {
                InsightsProContent()
            } else {
                InsightsLockedContent()
            }
        }
    }
}

// MARK: - PRO Content

private struct InsightsProContent: View {
    // Fetch up to 8 weeks, newest first. Insights caps at 8 because beyond that
    // the trend bar chart becomes unreadable on a phone screen.
    @Query(sort: \WeekCache.weekStartDate, order: .reverse) private var caches: [WeekCache]

    private var recentCaches: [WeekCache] { Array(caches.prefix(8)) }
    private var hasEnoughForPatterns: Bool { recentCaches.count >= 2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if ProService.isTestFlight {
                    betaBanner
                }

                headerSection

                WeeklyTrendCard(caches: recentCaches)

                if hasEnoughForPatterns {
                    PatternCalloutCard(caches: recentCaches)
                    PatternCoachingCard(caches: recentCaches)
                } else {
                    BuildingDataCard()
                }
            }
            .padding(NimvaLayout.screenPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var betaBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.system(size: 13))
                .foregroundStyle(NimvaColors.amberWarm)
            VStack(alignment: .leading, spacing: 2) {
                Text("Beta build — PRO unlocked")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NimvaColors.amberWarm)
                Text("Insights are free to use while you're testing. Thanks for being a beta tester!")
                    .font(.system(size: 11))
                    .foregroundStyle(NimvaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NimvaColors.amberWarm.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(NimvaColors.amberWarm.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("INSIGHTS")
                .font(NimvaFont.sectionLabel)
                .foregroundStyle(NimvaColors.textMuted)
                .tracking(1.2)
            Text("Your energy over time")
                .font(NimvaFont.pageTitle)
                .foregroundStyle(NimvaColors.textPrimary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Weekly Trend Card

// Stored as a String so AppStorage can persist it across launches without a custom encoder.
private enum TrendStyle: String {
    case wave, bars
}

private struct WeeklyTrendCard: View {
    let caches: [WeekCache]

    // Persisted permanently — user sets this once and never thinks about it again.
    // Wave is the default: reads at a glance without requiring number-by-number comparison,
    // which matters for ADHD users who process patterns before detail.
    @AppStorage("insightsTrendStyle") private var trendStyle: TrendStyle = .wave
    @AppStorage("useAltEnergyPalette") private var useAltPalette = false

    // Oldest → newest so the chart reads left to right naturally
    private var chartData: [WeekDatum] {
        caches.reversed().map {
            WeekDatum(
                label: shortDateLabel($0.weekStartDate),
                heavyDayCount: $0.heavyDayValues.count,
                weekStartDate: $0.weekStartDate
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if chartData.isEmpty {
                emptyState
            } else {
                Group {
                    if trendStyle == .wave {
                        waveChart
                    } else {
                        barChart
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: trendStyle)

                legendRow
            }
        }
        .padding(NimvaLayout.cardPadding)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text("WEEKLY LOAD")
                .font(NimvaFont.sectionLabel)
                .foregroundStyle(NimvaColors.textMuted)
                .tracking(1.0)

            Spacer()

            // Persistent style toggle — two icon buttons, selected one highlighted
            HStack(spacing: 0) {
                styleToggleButton(.wave,  icon: "waveform")
                styleToggleButton(.bars,  icon: "chart.bar.fill")
            }
            .padding(3)
            .background(NimvaColors.surfaceDeep)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func styleToggleButton(_ style: TrendStyle, icon: String) -> some View {
        let isSelected = trendStyle == style
        Button {
            trendStyle = style
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? NimvaColors.textPrimary : NimvaColors.textMuted)
                .frame(width: 32, height: 28)
                .background(isSelected ? NimvaColors.purpleMuted : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        // Accessibility: announce which view this switches to, not just the icon
        .accessibilityLabel(style == .wave ? "Wave view" : "Bar chart view")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Wave chart

    private var waveChart: some View {
        Chart(chartData) { datum in
            // Soft gradient fill under the curve — adds depth without competing with the line
            AreaMark(
                x: .value("Week", datum.label),
                y: .value("Heavy days", datum.heavyDayCount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [NimvaColors.purplePrimary.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Week", datum.label),
                y: .value("Heavy days", datum.heavyDayCount)
            )
            .foregroundStyle(NimvaColors.purplePrimary)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))

            // Colored dots show severity; number annotation below so detail
            // is available without needing to read the y-axis
            PointMark(
                x: .value("Week", datum.label),
                y: .value("Heavy days", datum.heavyDayCount)
            )
            .foregroundStyle(severityColor(for: datum.heavyDayCount))
            .symbolSize(64)
            .annotation(position: .bottom, spacing: 4) {
                Text("\(datum.heavyDayCount)")
                    .font(NimvaFont.micro)
                    .foregroundStyle(NimvaColors.textMuted)
            }
        }
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(values: [0, 7]) { _ in
                AxisGridLine().foregroundStyle(NimvaColors.border.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(NimvaColors.textMuted)
                    .font(NimvaFont.micro)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(NimvaColors.textMuted)
                    .font(NimvaFont.micro)
            }
        }
        .frame(height: 180)
    }

    // MARK: Bar chart

    private var barChart: some View {
        Chart(chartData) { datum in
            BarMark(
                x: .value("Week", datum.label),
                y: .value("Heavy days", datum.heavyDayCount)
            )
            .foregroundStyle(severityColor(for: datum.heavyDayCount))
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(values: [0, 2, 4, 7]) { _ in
                AxisGridLine().foregroundStyle(NimvaColors.border.opacity(0.4))
                AxisValueLabel()
                    .foregroundStyle(NimvaColors.textMuted)
                    .font(NimvaFont.micro)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .foregroundStyle(NimvaColors.textMuted)
                    .font(NimvaFont.micro)
            }
        }
        .frame(height: 160)
    }

    // MARK: Shared

    private var emptyState: some View {
        Text("Generate your first week in the Plan tab to start tracking your energy.")
            .font(NimvaFont.body)
            .foregroundStyle(NimvaColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(NimvaColors.energyLight(useAltPalette), "Light (0–1)")
            legendItem(NimvaColors.energyMixed(useAltPalette), "Mixed (2–3)")
            legendItem(NimvaColors.energyHeavy(useAltPalette), "Heavy (4+)")
        }
        .font(NimvaFont.micro)
        .foregroundStyle(NimvaColors.textSecondary)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }

    // Thresholds: 0–1 = light week, 2–3 = mixed, 4+ = heavy
    private func severityColor(for heavyDayCount: Int) -> Color {
        switch heavyDayCount {
        case 0...1: return NimvaColors.energyLight(useAltPalette)
        case 2...3: return NimvaColors.energyMixed(useAltPalette)
        default:    return NimvaColors.energyHeavy(useAltPalette)
        }
    }

    private func shortDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

// Flat struct for Chart — avoids passing WeekCache (a SwiftData model) directly
// into the Charts framework, which can cause observation conflicts.
private struct WeekDatum: Identifiable {
    let id = UUID()
    let label: String
    let heavyDayCount: Int
    let weekStartDate: Date
}

// MARK: - Pattern Callout Card

private struct PatternCalloutCard: View {
    let caches: [WeekCache]

    private var patterns: [PatternCallout] { detectPatterns(from: caches) }

    var body: some View {
        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Patterns", systemImage: "waveform.path")
                    .font(NimvaFont.sectionLabel)
                    .foregroundStyle(NimvaColors.textMuted)
                    .tracking(1.0)

                ForEach(patterns) { pattern in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(NimvaColors.amber)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(pattern.headline)
                                .font(NimvaFont.cardTitle)
                                .foregroundStyle(NimvaColors.textPrimary)
                            Text(pattern.detail)
                                .font(NimvaFont.body)
                                .foregroundStyle(NimvaColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(NimvaLayout.cardPadding)
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
        }
    }
}

private struct PatternCallout: Identifiable {
    let id = UUID()
    let headline: String
    let detail: String
    let coaching: String
}

// A day is a "pattern" when it appears as heavy in ≥50% of available weeks,
// with a hard minimum of 2 weeks so we don't flag a single bad Tuesday as a pattern.
// Returns at most 2 callouts — more than that clutters the card.
private func detectPatterns(from caches: [WeekCache]) -> [PatternCallout] {
    guard caches.count >= 2 else { return [] }

    var dayCounts: [DayOfWeek: Int] = [:]
    for cache in caches {
        for rawValue in cache.heavyDayValues {
            if let day = DayOfWeek(rawValue: rawValue) {
                dayCounts[day, default: 0] += 1
            }
        }
    }

    let threshold = max(2, Int((Double(caches.count) * 0.5).rounded(.up)))
    var patterns: [PatternCallout] = dayCounts
        .filter { $0.value >= threshold }
        .sorted { $0.value > $1.value }
        .prefix(2)
        .map { day, count in
            PatternCallout(
                headline: "\(day.displayName)s have been consistently heavy",
                detail: "That's \(count) of your last \(caches.count) weeks. If something is anchored there, this might be worth a conversation — with a coach, advisor, or just yourself.",
                coaching: coachingSentence(for: day, count: count, totalWeeks: caches.count)
            )
        }

    // Recovery pattern: track whether lighter weeks are actually providing rest
    let recoveryWeeks = caches.filter { $0.wasRecoveryWeek && $0.recoveryCheckInRaw != nil }
    if recoveryWeeks.count >= 2 {
        let notRecovered = recoveryWeeks.filter { $0.recoveryCheckInRaw == 3 }.count
        let ratio = Double(notRecovered) / Double(recoveryWeeks.count)
        if ratio >= 0.6 {
            patterns.append(PatternCallout(
                headline: "Your lighter weeks aren't feeling like rest",
                detail: "\(notRecovered) of your last \(recoveryWeeks.count) lighter weeks still felt draining. A lighter schedule doesn't automatically mean recovery — what happens in that space matters.",
                coaching: "A lighter week is only recovery if it's actually used that way. Worth thinking about what fills that time — and whether it's actually restoring you."
            ))
        } else if ratio <= 0.25 && recoveryWeeks.count >= 3 {
            patterns.append(PatternCallout(
                headline: "Your lighter weeks are actually recharging you",
                detail: "\(recoveryWeeks.count - notRecovered) of your last \(recoveryWeeks.count) lighter weeks felt like real rest. That's a pattern worth protecting.",
                coaching: "You're using your lighter weeks well. That kind of deliberate recovery is harder than it looks — keep it."
            ))
        }
    }

    return patterns
}

private func coachingSentence(for day: DayOfWeek, count: Int, totalWeeks: Int) -> String {
    switch count {
    case 2...3:
        return "\(day.displayName) is starting to look like a pattern. If there's a fixed commitment anchored there, it might be worth thinking about whether anything around it can shift — even small things."
    case 4...5:
        return "\(day.displayName) has been heavy \(count) weeks in a row. Something is likely anchored there. That kind of sustained load is worth a real conversation — with a coach, advisor, or even just yourself. You're not imagining it."
    default:
        return "\(count) heavy \(day.displayName)s in a row is a significant signal. This isn't just a rough stretch — it's a structural pattern. If the load can't move, naming that clearly is still useful. It's data you can bring to someone."
    }
}

// MARK: - Pattern Coaching Card

// One coaching sentence per detected pattern, in Ember's calm observer voice.
// Shown below PatternCalloutCard so the headline + detail land first, coaching follows.
private struct PatternCoachingCard: View {
    let caches: [WeekCache]

    private var patterns: [PatternCallout] { detectPatterns(from: caches) }

    var body: some View {
        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label("What this might mean", systemImage: "bubble.left")
                    .font(NimvaFont.sectionLabel)
                    .foregroundStyle(NimvaColors.textMuted)
                    .tracking(1.0)
                    .accessibilityAddTraits(.isHeader)

                ForEach(patterns) { pattern in
                    HStack(alignment: .top, spacing: 12) {
                        EmberView(expression: .calm, size: .mini)
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)

                        Text(pattern.coaching)
                            .font(NimvaFont.body)
                            .foregroundStyle(NimvaColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(NimvaColors.surfaceDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Ember says: \(pattern.coaching)")
                }
            }
            .padding(NimvaLayout.cardPadding)
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
        }
    }
}

// MARK: - Building Data Card

private struct BuildingDataCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("✨")
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text("Building your picture")
                    .font(NimvaFont.cardTitle)
                    .foregroundStyle(NimvaColors.textPrimary)
                Text("Generate a few more weeks and your energy patterns will start to appear here.")
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NimvaLayout.cardPadding)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }
}

// MARK: - Locked Content

private struct InsightsLockedContent: View {
    @Environment(ProService.self) private var proService

    @State private var showingPurchaseError = false

    // Fake bar heights for the decorative blurred background.
    // These are never derived from real user data — the spec requires the
    // locked view to show only generic placeholder visuals.
    private let mockBars: [CGFloat] = [28, 84, 56, 112, 28, 84, 42]

    var body: some View {
        ZStack {
            blurredBackground
            upgradeCard
                .padding(NimvaLayout.screenPadding)
        }
        .alert("Purchase failed", isPresented: $showingPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Something went wrong. Please check your connection and try again.")
        }
    }

    private var blurredBackground: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(mockBars.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NimvaColors.purplePrimary.opacity(0.45))
                        .frame(width: 32, height: mockBars[i])
                }
            }
            .padding(.bottom, 80)
        }
        .blur(radius: 14)
        .allowsHitTesting(false) // purely decorative — never intercepts taps
        .accessibilityHidden(true)
    }

    private var upgradeCard: some View {
        VStack(spacing: 20) {
            // Ember with lock badge
            ZStack(alignment: .bottomTrailing) {
                EmberView(expression: .calm, size: .big)
                    .frame(width: 88, height: 88)
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NimvaColors.amber)
                    .padding(6)
                    .background(NimvaColors.cardDark)
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
            }

            VStack(spacing: 8) {
                Text("Your energy patterns, over time")
                    .font(NimvaFont.pageTitle)
                    .foregroundStyle(NimvaColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("See why certain weeks keep feeling heavy — and bring that data to a conversation that matters.")
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("5-week energy trend at a glance")
                bullet("Pattern callouts — why Tuesdays keep being hard")
                bullet("Evidence you can bring to a coach or counselor")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Free for 2 weeks. No charge until day 15. Cancel anytime.")
                .font(NimvaFont.micro)
                .foregroundStyle(NimvaColors.textMuted)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    Task {
                        do {
                            try await proService.purchase()
                        } catch {
                            showingPurchaseError = true
                        }
                    }
                } label: {
                    Group {
                        if proService.purchaseInProgress {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Try PRO free for 2 weeks")
                                .font(NimvaFont.cardTitle)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NimvaColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.inputRadius))
                }
                .disabled(proService.purchaseInProgress)

                // App Store guidelines require a visible restore option wherever
                // a subscription purchase button appears.
                Button {
                    Task { await proService.restorePurchases() }
                } label: {
                    Text("Restore purchase")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(NimvaColors.teal)
                .font(NimvaFont.body)
            Text(text)
                .font(NimvaFont.body)
                .foregroundStyle(NimvaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Locked — free user") {
    ZStack {
        NimvaColors.background.ignoresSafeArea()
        InsightsLockedContent()
    }
    .environment(ProService())
}

#Preview("Unlocked — PRO user") {
    InsightsView()
        .environment(ProService())
        .modelContainer(for: [WeekCache.self], inMemory: true)
}
