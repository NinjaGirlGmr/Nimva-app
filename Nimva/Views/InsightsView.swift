import SwiftUI
import SwiftData
import Charts

// MARK: - InsightsView
// Routes to PRO content or the locked upgrade screen based on subscription status.
// The @Query lives inside InsightsProContent so SwiftData never fetches history
// for non-PRO users — no real data is computed or shown behind the lock.
struct InsightsView: View {
    @Environment(ProService.self) private var proService
    // Beta testers are always auto-PRO via ProService.isTestFlight, so without this they'd
    // have no way to see what the free/locked experience even looks like. Toggled in Settings
    // → Beta Testing, off by default, reversible anytime.
    @AppStorage("betaPreviewLockedInsights") private var previewLockedInsights = false

    private var showBetaLockedPreview: Bool {
        ProService.isTestFlight && previewLockedInsights
    }

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            if showBetaLockedPreview {
                BetaLockedPreviewContent()
            } else if proService.isProEnabled {
                InsightsProContent()
            } else {
                InsightsLockedContent()
            }
        }
    }
}

// MARK: - Beta Locked Preview (TestFlight only)

// A simplified stand-in for the real locked view — deliberately just a lock, no Ember and
// no purchase flow, since this isn't a real upsell moment, just letting a beta tester see
// what a free user's Insights tab looks like without losing their own PRO access.
private struct BetaLockedPreviewContent: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Beta testers can turn this off in Settings")
                .font(NimvaFont.micro)
                .foregroundStyle(NimvaColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 24)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(NimvaColors.amber)

            Text("Insights, locked")
                .font(NimvaFont.pageTitle)
                .foregroundStyle(NimvaColors.textPrimary)

            Text("This is what the Insights tab looks like for a free user, before upgrading to PRO.")
                .font(NimvaFont.body)
                .foregroundStyle(NimvaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - PRO Content

private struct InsightsProContent: View {
    // Fetch up to 8 weeks, newest first. Insights caps at 8 because beyond that
    // the trend bar chart becomes unreadable on a phone screen.
    @Query(sort: \WeekCache.weekStartDate, order: .reverse) private var caches: [WeekCache]
    @Query(sort: \Event.createdAt) private var events: [Event]

    // Excludes future (rolling-calendar) weeks — Insights trend/pattern data must only ever
    // reflect weeks that have actually happened, never one still being planned or redone.
    private var recentCaches: [WeekCache] {
        Array(caches.filter { $0.weekStartDate <= SchedulerService.weekStart() }.prefix(8))
    }
    private var hasEnoughForPatterns: Bool { recentCaches.count >= 2 }

    // Every other screen (EnergyZoneCard, WeekGenerationView, HomeView) already shifts its
    // framing by user type — Insights hadn't, even though "what should I actually do about
    // this pattern" is exactly where an Optimizer (real flexibility to rearrange) and an
    // Overloaded Fixed user (little to nothing movable) need genuinely different sentences,
    // not the same one softened or sharpened. See detectPatterns/coachingSentence below.
    private var userType: UserType {
        SchedulerService.detectUserType(events: events)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if ProService.isTestFlight {
                    betaBanner
                }

                headerSection

                WeeklyTrendCard(caches: recentCaches)

                if !recentCaches.isEmpty {
                    AdvancedInsightsSection(caches: recentCaches)
                }

                if hasEnoughForPatterns {
                    PatternCalloutCard(caches: recentCaches, userType: userType)
                    PatternCoachingCard(caches: recentCaches, userType: userType)
                } else {
                    BuildingDataCard()
                }

                // Independent of week history — driven by tagged event count, not weeks built.
                CategoryPatternCard()
            }
            .padding(NimvaLayout.screenPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var betaBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(NimvaFont.body)
                .foregroundStyle(NimvaColors.amberWarm)
            VStack(alignment: .leading, spacing: 2) {
                Text("Beta build — PRO unlocked")
                    .font(NimvaFont.captionSemi)
                    .foregroundStyle(NimvaColors.amberWarm)
                Text("Insights are free to use while you're testing. Thanks for being a beta tester!")
                    .font(NimvaFont.micro)
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
    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Oldest → newest so the chart reads left to right naturally. weekData(from:) is shared
    // with DayBreakdownChart — see its definition for why.
    private var chartData: [WeekDatum] { weekData(from: caches) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if chartData.isEmpty {
                emptyState
            } else {
                if let text = weekOverWeekText {
                    weekOverWeekRow(text)
                }

                Group {
                    if trendStyle == .wave {
                        waveChart
                    } else {
                        barChart
                    }
                }
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: trendStyle)

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
                .font(NimvaFont.bodyMedium)
                .foregroundStyle(isSelected ? NimvaColors.textPrimary : NimvaColors.textMuted)
                .frame(width: 32, height: 28)
                .background(isSelected ? NimvaColors.purpleMuted : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle().size(CGSize(width: 44, height: 44)))
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
        // Chart canvases don't reflow the way stacks do — the plot area is a fixed frame,
        // not something axis labels/annotations can grow into. Capped at the same ceiling
        // as WeekStripView's day labels for the same reason: legible and meaningfully
        // larger, without letting axis text collide inside a frame that can't grow to match.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(height: 200)
    }

    // MARK: Bar chart

    // Deliberately the SAME metric as waveChart (heavy-day count per week) — just as bars
    // instead of a line. This card stays the simple, glanceable overview either way; the
    // real light/mixed/heavy-per-day breakdown lives in AdvancedInsightsSection below,
    // opt-in rather than always visible, so this default view never requires comparing
    // more than one number per week to read at a glance.
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
        // See waveChart's matching modifier above for why this is capped rather than left
        // to scale freely.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(height: 180)
    }

    // MARK: Shared

    private var emptyState: some View {
        Text("Generate your first week in the Plan tab to start tracking your energy.")
            .font(NimvaFont.body)
            .foregroundStyle(NimvaColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
    }

    // Both wave and bar show the same metric (heavy-day count per week), so the numeric
    // ranges here are accurate again — they describe how many heavy days make a week
    // "Light/Mixed/Heavy" overall, matching severityColor(for:)'s own boundaries exactly.
    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(Color(hex: energyLightHex), "Light (0–1)")
            legendItem(Color(hex: energyMixedHex), "Mixed (2–3)")
            legendItem(Color(hex: energyHeavyHex), "Heavy (4+)")
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

    // MARK: Week-over-week

    // `caches` is newest-first (order: .reverse) and already limited to the current week
    // and earlier — [0] is this week's (possibly still-in-progress, but a built week's
    // heavy-day count reflects the whole planned week, not just days elapsed so far) and
    // [1] is the one directly before it. nil when there isn't yet a full pair to compare.
    private var weekOverWeekDelta: (current: Int, previous: Int)? {
        guard caches.count >= 2 else { return nil }
        return (caches[0].heavyDayValues.count, caches[1].heavyDayValues.count)
    }

    private var weekOverWeekText: String? {
        guard let delta = weekOverWeekDelta else { return nil }
        let dayWord = "\(delta.current) heavy day\(delta.current == 1 ? "" : "s")"
        switch delta.current - delta.previous {
        case ..<0: return "\(dayWord) this week, down from \(delta.previous) last week."
        case 0:    return "\(dayWord) this week — same as last week."
        default:   return "\(dayWord) this week, up from \(delta.previous) last week."
        }
    }

    private var weekOverWeekIcon: String {
        guard let delta = weekOverWeekDelta else { return "minus" }
        switch delta.current - delta.previous {
        case ..<0: return "arrow.down.right"
        case 0:    return "minus"
        default:   return "arrow.up.right"
        }
    }

    private func weekOverWeekRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: weekOverWeekIcon)
                .font(NimvaFont.micro)
                .accessibilityHidden(true)
            Text(text)
                .font(NimvaFont.micro)
        }
        // Reuses the same light/mixed/heavy color already used for the chart and legend
        // below, so this isn't introducing a fourth color meaning into the same card —
        // and the words "up"/"down"/"same" carry the actual meaning regardless of color.
        .foregroundStyle(severityColor(for: weekOverWeekDelta?.current ?? 0))
        .accessibilityElement(children: .combine)
    }

    // Thresholds: 0–1 = light week, 2–3 = mixed, 4+ = heavy
    private func severityColor(for heavyDayCount: Int) -> Color {
        switch heavyDayCount {
        case 0...1: return Color(hex: energyLightHex)
        case 2...3: return Color(hex: energyMixedHex)
        default:    return Color(hex: energyHeavyHex)
        }
    }

}

// Shared "M/d" short date label — used by WeeklyTrendCard, DayBreakdownChart, and
// DayPatternGrid, all of which label a week by its start date the same way. One copy
// instead of three so a format change can't accidentally land in only some of them.
private func shortDateLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "M/d"
    return f.string(from: date)
}

// Shared week → WeekDatum mapping (oldest to newest, so charts read left to right
// naturally) — used by both WeeklyTrendCard and DayBreakdownChart. One copy so a change to
// what a WeekDatum carries doesn't require remembering to update two independent copies.
private func weekData(from caches: [WeekCache]) -> [WeekDatum] {
    caches.reversed().map {
        WeekDatum(
            label: shortDateLabel($0.weekStartDate),
            heavyDayCount: $0.heavyDayValues.count,
            weekStartDate: $0.weekStartDate,
            dailyLoadValues: $0.dailyLoadValues
        )
    }
}

// Flat struct for Chart — avoids passing WeekCache (a SwiftData model) directly
// into the Charts framework, which can cause observation conflicts.
private struct WeekDatum: Identifiable {
    let id = UUID()
    let label: String
    let heavyDayCount: Int
    let weekStartDate: Date
    // Index 0 = Monday ... 6 = Sunday. Empty for any WeekCache built before this field
    // existed — daySeverities/lightCount/etc. all degrade to empty/zero gracefully rather
    // than crashing on a missing index.
    let dailyLoadValues: [Double]

    // Reuses the exact boundary every other load display in the app already uses
    // (WeekStripView's day dots, EnergyZoneCard) — never a second copy that can drift.
    var daySeverities: [LoadSeverity] { dailyLoadValues.map { LoadSeverity.forLoad($0) } }
    var lightCount: Int    { daySeverities.filter { $0 == .light }.count }
    var moderateCount: Int { daySeverities.filter { $0 == .moderate }.count }
    var heavyCount: Int    { daySeverities.filter { $0 == .heavy }.count }
}

// MARK: - Advanced Insights Section

// Opt-in home for the detailed, comparison-heavy views (the stacked day breakdown and the
// day-pattern grid) — collapsed by default so the main screen stays a quick scan (trend,
// pattern callouts, category card) and nobody has to parse a grid before getting to the
// easy stuff. Matches the DisclosureGroup "Advanced" pattern already used in
// AddEventView/EditEventView, for the same reason: occasional-use depth, not front-loaded.
private struct AdvancedInsightsSection: View {
    let caches: [WeekCache]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 20) {
                    DayBreakdownChart(caches: caches)
                    DayPatternGrid(caches: caches)
                }
                .padding(.top, 16)
            } label: {
                Label("Advanced view", systemImage: "chart.bar.doc.horizontal")
                    .font(NimvaFont.sectionLabel)
                    .foregroundStyle(NimvaColors.textMuted)
                    .tracking(1.0)
            }
            .tint(NimvaColors.textMuted)
        }
        .padding(NimvaLayout.cardPadding)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }
}

// Same underlying data as WeeklyTrendCard's barChart used to show inline — light/mixed/heavy
// DAY counts stacked per week, not just a heavy-day count. Colors match legendRow's meaning
// (a single day's own severity, same vocabulary as WeekStripView's day dots), which is why
// this couldn't just stay merged into the simple card: it measures something genuinely
// different from "how many heavy days," and conflating the two in one legend was the
// original tester confusion this whole redesign started from.
private struct DayBreakdownChart: View {
    let caches: [WeekCache]

    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"

    private var chartData: [WeekDatum] { weekData(from: caches) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Light / mixed / heavy days per week")
                .font(NimvaFont.micro)
                .foregroundStyle(NimvaColors.textMuted)

            Chart {
                ForEach(chartData) { datum in
                    ForEach(severityBreakdown(for: datum), id: \.label) { entry in
                        BarMark(
                            x: .value("Week", datum.label),
                            y: .value("Days", entry.count)
                        )
                        .foregroundStyle(by: .value("Severity", entry.label))
                        .cornerRadius(2)
                    }
                }
            }
            .chartForegroundStyleScale([
                "Light": Color(hex: energyLightHex),
                "Mixed": Color(hex: energyMixedHex),
                "Heavy": Color(hex: energyHeavyHex)
            ])
            // The outer card's legendRow describes the simple wave/bar meaning, not this
            // chart's — Charts' own per-series legend here avoids implying they're the same.
            .chartYScale(domain: 0...7)
            .chartYAxis {
                AxisMarks(values: [0, 7]) { _ in
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
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .frame(height: 180)
        }
    }

}

private func severityBreakdown(for datum: WeekDatum) -> [(label: String, count: Int)] {
    [
        (label: "Light", count: datum.lightCount),
        (label: "Mixed", count: datum.moderateCount),
        (label: "Heavy", count: datum.heavyCount)
    ]
}

// MARK: - Day Pattern Grid

// The literal "breakdown of trends for each day" — a day-of-week × week grid, newest week
// at top (matches `caches`' own order, no reversal needed). Reading down a column shows one
// weekday's history across weeks at a glance; reading across a row shows that week's shape.
// Complements WeeklyTrendCard (which reads left-to-right through time) rather than
// duplicating it — this is about a specific weekday's pattern, not the week-over-week trend.
private struct DayPatternGrid: View {
    let caches: [WeekCache]

    @AppStorage("customEnergyLightHex") private var energyLightHex = "1d9e75"
    @AppStorage("customEnergyMixedHex") private var energyMixedHex = "ef9f27"
    @AppStorage("customEnergyHeavyHex") private var energyHeavyHex = "e0825a"

    private var orderedDays: [DayOfWeek] { DayOfWeek.orderedForLocale }
    private let rowLabelWidth: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("By day of week", systemImage: "square.grid.3x3")
                .font(NimvaFont.sectionLabel)
                .foregroundStyle(NimvaColors.textMuted)
                .tracking(1.0)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Color.clear.frame(width: rowLabelWidth, height: 1)
                    ForEach(orderedDays, id: \.self) { day in
                        Text(day.shortName.prefix(1))
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)   // the per-row accessibility label already
                                              // names each day; this header is visual-only

                ForEach(caches) { cache in
                    HStack(spacing: 6) {
                        Text(shortDateLabel(cache.weekStartDate))
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                            .frame(width: rowLabelWidth, alignment: .leading)

                        ForEach(orderedDays, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(for: day, in: cache))
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: cache))
                }
            }
        }
        .padding(NimvaLayout.cardPadding)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }

    // Empty (not a severity color) when this WeekCache predates dailyLoadValues, or that
    // day just isn't in range yet — surfaceDeep reads as "no data," not as a fourth
    // severity tier, so it can't be mistaken for an especially-light day.
    private func cellColor(for day: DayOfWeek, in cache: WeekCache) -> Color {
        let index = day.rawValue - 1
        guard cache.dailyLoadValues.indices.contains(index) else {
            return NimvaColors.surfaceDeep
        }
        let severity = LoadSeverity.forLoad(cache.dailyLoadValues[index])
        return Color(hex: severity.hex(light: energyLightHex, mixed: energyMixedHex, heavy: energyHeavyHex))
    }

    private func accessibilityLabel(for cache: WeekCache) -> String {
        let parts = orderedDays.map { day -> String in
            let index = day.rawValue - 1
            guard cache.dailyLoadValues.indices.contains(index) else {
                return "\(day.displayName) no data"
            }
            let severity = LoadSeverity.forLoad(cache.dailyLoadValues[index])
            let word = switch severity {
            case .light: "light"
            case .moderate: "mixed"
            case .heavy: "heavy"
            }
            return "\(day.displayName) \(word)"
        }
        return "Week of \(shortDateLabel(cache.weekStartDate)): " + parts.joined(separator: ", ")
    }
}

// MARK: - Pattern Callout Card

private struct PatternCalloutCard: View {
    let caches: [WeekCache]
    let userType: UserType

    private var patterns: [PatternCallout] { detectPatterns(from: caches, userType: userType) }

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
private func detectPatterns(from caches: [WeekCache], userType: UserType) -> [PatternCallout] {
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
                detail: patternDetail(for: day, count: count, totalWeeks: caches.count, userType: userType),
                coaching: coachingSentence(for: day, count: count, totalWeeks: caches.count, userType: userType)
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
                detail: "\(notRecovered) of your last \(recoveryWeeks.count) lighter weeks still felt draining. A lighter schedule doesn't automatically mean recovery — what happens during that time matters.",
                coaching: "A lighter week is only recovery if it's actually used that way. Worth thinking about what fills that time — and whether it's actually restoring you."
            ))
        } else if ratio <= 0.25 && recoveryWeeks.count >= 3 {
            patterns.append(PatternCallout(
                headline: "Your lighter weeks are actually recharging you",
                detail: "\(recoveryWeeks.count - notRecovered) of your last \(recoveryWeeks.count) lighter weeks felt like real rest. That's a pattern worth keeping up.",
                coaching: "You're using your lighter weeks well. That kind of deliberate recovery takes more effort than people usually realize — keep it up."
            ))
        }
    }

    return patterns
}

// Same underlying pattern, three different "what should I actually do" answers — an
// Optimizer has real flexibility to test against the pattern, an Overloaded Fixed user
// mostly doesn't (so the honest answer is validation, not a suggestion to rearrange
// something that can't move), and a Pattern Learner is still building enough weeks to
// know which one they are yet. See CLAUDE.md's "User Types" section for the source of
// this split — it's already applied everywhere else in the app except here.
private func coachingSentence(for day: DayOfWeek, count: Int, totalWeeks: Int, userType: UserType) -> String {
    switch userType {
    case .optimizer:
        switch count {
        case 2...3:
            return "\(day.displayName) is starting to look like a pattern. Worth checking whether flexible events keep landing there by default — if so, a different placement might be worth trying."
        case 4...5:
            return "\(day.displayName) has been heavy for \(count) consecutive weeks. If fixed commitments are driving that, there may not be much to move — but if flexible events keep stacking there too, that's worth rethinking."
        default:
            return "\(count) heavy \(day.displayName)s in \(count) consecutive weeks is a clear pattern. Worth a closer look at what's actually landing there each week, and whether it has to."
        }
    case .overloadedFixed:
        switch count {
        case 2...3:
            return "\(day.displayName) is starting to look like a pattern. Worth noticing, even if nothing about it can change right now — that's still useful to know."
        case 4...5:
            return "\(day.displayName) has been heavy for \(count) consecutive weeks. Something is likely fixed there. That kind of sustained load is worth a real conversation — with a coach, advisor, or even just yourself. You're not imagining it."
        default:
            return "\(count) heavy \(day.displayName)s in \(count) consecutive weeks is a significant signal. This isn't just a difficult few weeks — it's a structural pattern. If the load can't move, naming that clearly is still useful. It's data you can bring to someone."
        }
    case .patternLearner:
        switch count {
        case 2...3:
            return "\(day.displayName) is starting to look like a pattern. A couple more weeks will make it clearer whether this is really about that day, or something that tends to land on it."
        case 4...5:
            return "\(day.displayName) has been heavy for \(count) consecutive weeks. That's a real pattern worth understanding — is it the day itself, or what usually gets scheduled on it?"
        default:
            return "\(count) heavy \(day.displayName)s in \(count) consecutive weeks is a clear, established pattern. That's real data about how your energy actually moves through the week."
        }
    }
}

// The callout's factual line, right above the coaching sentence — same three-way split
// and same reasoning (see coachingSentence above).
private func patternDetail(for day: DayOfWeek, count: Int, totalWeeks: Int, userType: UserType) -> String {
    switch userType {
    case .optimizer:
        return "That's \(count) of your last \(totalWeeks) weeks. Worth a look at what's actually being scheduled there — if it's flexible events, there may be room to rearrange."
    case .overloadedFixed:
        return "That's \(count) of your last \(totalWeeks) weeks. If something is fixed in place there, this might be worth a conversation — with a coach, advisor, or just yourself."
    case .patternLearner:
        return "That's \(count) of your last \(totalWeeks) weeks. Worth watching a few more weeks to see if this holds — patterns like this are exactly what Insights is for."
    }
}

// MARK: - Pattern Coaching Card

// One coaching sentence per detected pattern, in Ember's calm observer voice.
// Shown below PatternCalloutCard so the headline + detail land first, coaching follows.
private struct PatternCoachingCard: View {
    let caches: [WeekCache]
    let userType: UserType

    private var patterns: [PatternCallout] { detectPatterns(from: caches, userType: userType) }

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

// MARK: - Category Pattern Card

// Surfaces PatternService's learned per-category baselines — purely observational, matches
// the rest of Insights' "evidence, not a directive" tone. Never feeds back into scheduling.
private struct CategoryPatternCard: View {
    private var patterns: [CategoryPattern] {
        categoryPatterns(baselines: PatternService.shared.baselines, counts: PatternService.shared.recordedCounts)
    }

    var body: some View {
        if !patterns.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Category patterns", systemImage: "tag")
                    .font(NimvaFont.sectionLabel)
                    .foregroundStyle(NimvaColors.textMuted)
                    .tracking(1.0)

                ForEach(patterns) { pattern in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(NimvaColors.teal)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(pattern.category) tends to run \"\(pattern.label.displayName)\"")
                                .font(NimvaFont.cardTitle)
                                .foregroundStyle(NimvaColors.textPrimary)
                            Text("Based on \(pattern.count) tagged \(pattern.category) events.")
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

// MARK: - Building Data Card

private struct BuildingDataCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("✨")
                .font(.system(.title))

            VStack(alignment: .leading, spacing: 4) {
                Text("Still gathering data")
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
                    .font(.system(.callout, weight: .bold))
                    .foregroundStyle(NimvaColors.amber)
                    .padding(6)
                    .background(NimvaColors.cardDark)
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
                    .accessibilityHidden(true)
            }

            // Grouped into one VoiceOver stop instead of 7+ fragmented reads (title,
            // subtitle, 3 bullet icons + text, fine print) — this is explanatory content
            // read in order, not individually interactive.
            VStack(spacing: 20) {
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
                    bullet("5-week energy trend in one view")
                    bullet("Pattern callouts — why Tuesdays keep being hard")
                    bullet("Evidence you can bring to a coach or counselor")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Free for 2 weeks. No charge until day 15. Cancel anytime.")
                    .font(NimvaFont.micro)
                    .foregroundStyle(NimvaColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

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
                .accessibilityHidden(true)
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
