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
                headerSection

                WeeklyTrendCard(caches: recentCaches)

                if hasEnoughForPatterns {
                    PatternCalloutCard(caches: recentCaches)
                } else {
                    BuildingDataCard()
                }
            }
            .padding(NimvaLayout.screenPadding)
        }
        .scrollIndicators(.hidden)
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

private struct WeeklyTrendCard: View {
    let caches: [WeekCache]

    // Reverse so the chart reads oldest → newest (left to right)
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
            Label("Weekly load", systemImage: "chart.bar.fill")
                .font(NimvaFont.sectionLabel)
                .foregroundStyle(NimvaColors.textMuted)
                .tracking(1.0)

            if chartData.isEmpty {
                emptyState
            } else {
                trendChart
                legendRow
            }
        }
        .padding(NimvaLayout.cardPadding)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
    }

    private var emptyState: some View {
        Text("Generate your first week in the Plan tab to start tracking your energy.")
            .font(NimvaFont.body)
            .foregroundStyle(NimvaColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
    }

    private var trendChart: some View {
        Chart(chartData) { datum in
            BarMark(
                x: .value("Week", datum.label),
                y: .value("Heavy days", datum.heavyDayCount)
            )
            .foregroundStyle(barColor(for: datum.heavyDayCount))
            .cornerRadius(4)
        }
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(values: [0, 2, 4, 7]) { _ in
                AxisGridLine()
                    .foregroundStyle(NimvaColors.border.opacity(0.4))
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

    private var legendRow: some View {
        HStack(spacing: 16) {
            legendItem(NimvaColors.teal,  "Light (0–1)")
            legendItem(NimvaColors.amber, "Mixed (2–3)")
            legendItem(NimvaColors.coral, "Heavy (4+)")
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

    // Thresholds: 0–1 heavy days is a light week, 2–3 is mixed, 4+ is heavy
    private func barColor(for heavyDayCount: Int) -> Color {
        switch heavyDayCount {
        case 0...1: return NimvaColors.teal
        case 2...3: return NimvaColors.amber
        default:    return NimvaColors.coral
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
    return dayCounts
        .filter { $0.value >= threshold }
        .sorted { $0.value > $1.value }
        .prefix(2)
        .map { day, count in
            PatternCallout(
                headline: "\(day.displayName)s have been consistently heavy",
                detail: "That's \(count) of your last \(caches.count) weeks. If something is anchored there, this might be worth a conversation — with a coach, advisor, or just yourself."
            )
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
    }

    private var upgradeCard: some View {
        VStack(spacing: 20) {
            // Ember with lock badge
            ZStack(alignment: .bottomTrailing) {
                Text("😌")
                    .font(.system(size: 56))
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
                    Task { try? await proService.purchase() }
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
