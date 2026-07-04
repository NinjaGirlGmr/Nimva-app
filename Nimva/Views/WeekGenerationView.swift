import SwiftUI
import SwiftData

// Three phases of the week generation flow.
private enum GenerationState: Equatable {
    case ready      // before the user taps "Build my week"
    case building   // algorithm is running + animated reveal
    case done       // result is ready; user can approve or redo
}

struct WeekGenerationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.createdAt) private var events: [Event]

    @State private var genState: GenerationState = .ready
    @State private var progress: Double = 0.0
    // Holds the algorithm result so we can display placements without re-fetching
    @State private var schedule: WeekSchedule?
    // Which days have had their flexible events "dropped in" during the building animation
    @State private var revealedDays: Set<DayOfWeek> = []
    @State private var showingScheduleError = false

    private var fixedEvents: [Event]    { events.filter(\.isFixed) }
    private var flexibleEvents: [Event] { events.filter { !$0.isFixed } }
    private var userType: UserType      { SchedulerService.detectUserType(events: events) }

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerRow
                    dayGrid
                    if genState == .ready    { unscheduledSection }
                    if genState == .done     { insightChips }
                    emberCard
                    energyProgressBar
                    actionArea
                    Spacer(minLength: 40)
                }
                .padding(.top, 24)
                .padding(.horizontal, 16)
            }
        }
        .alert("Couldn't build your week", isPresented: $showingScheduleError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Something went wrong generating your schedule. Try again or restart the app if the problem persists.")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("This week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NimvaColors.textMuted)
                    .textCase(.uppercase)
                    .kerning(0.7)
                Text("Week generation")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(NimvaColors.textPrimary)
            }
            Spacer()
        }
    }

    // MARK: - Day grid

    // Seven equal-width columns, one per day.
    // In .ready state they're slightly taller to show event names;
    // in .building / .done they compress to narrow bars.
    private var isCompact: Bool { genState != .ready }

    private var dayGrid: some View {
        HStack(spacing: 6) {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                GenDayColumn(
                    day: day,
                    fixedEvents: fixedEvents.filter { $0.fixedDay == day },
                    placedFlexible: placedFlexibleOn(day),
                    // In .ready, all columns show their fixed anchors immediately.
                    // In .building, a day's flexible events appear only after it's been "revealed".
                    showFlexible: genState == .ready ? false : revealedDays.contains(day),
                    isCompact: isCompact
                )
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isCompact)
    }

    private func placedFlexibleOn(_ day: DayOfWeek) -> [Event] {
        guard let schedule else { return [] }
        let ids = Set(schedule.placedFlexibleEvents.filter { $0.day == day }.map(\.event.id))
        return events.filter { ids.contains($0.id) }
    }

    // MARK: - Unscheduled chips (ready state only)

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("To schedule")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .textCase(.uppercase)
                .kerning(0.7)

            if flexibleEvents.isEmpty {
                Text("No flexible events yet — add some with the + button on Home")
                    .font(.system(size: 13))
                    .foregroundStyle(NimvaColors.textMuted)
                    .padding(.vertical, 8)
            } else {
                // Wrapping chip layout using a LazyVGrid with adaptive columns
                let columns = [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(flexibleEvents) { event in
                        EventChip(event: event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Insight chips (done state only)

    @ViewBuilder
    private var insightChips: some View {
        if let schedule {
            VStack(spacing: 8) {
                if let heavyDay = schedule.heavyDays.sorted(by: { $0.rawValue < $1.rawValue }).first {
                    StatusChip(
                        icon: "exclamationmark.triangle.fill",
                        text: heavyDayChipText(for: heavyDay),
                        color: NimvaColors.amber
                    )
                }

                let activeDays = Set(
                    schedule.fixedEvents.map(\.day) +
                    schedule.placedFlexibleEvents.map(\.day)
                ).count
                StatusChip(
                    icon: "checkmark.circle.fill",
                    text: positiveChipText(activeDays: activeDays, flexPlaced: schedule.placedFlexibleEvents.count),
                    color: NimvaColors.teal
                )
            }
        }
    }

    // Plain functions, not @ViewBuilder — switch statements here behave normally.
    private func heavyDayChipText(for day: DayOfWeek) -> String {
        switch userType {
        case .optimizer:      return "\(day.displayName) looks heavy — consider moving something"
        case .overloadedFixed: return "\(day.displayName) is packed — most of this is fixed, I've noted the load"
        case .patternLearner: return "\(day.displayName) looks heavy — I've routed flex tasks around it"
        }
    }

    private func positiveChipText(activeDays: Int, flexPlaced: Int) -> String {
        switch userType {
        case .optimizer:
            return "Energy spread across \(activeDays) day\(activeDays == 1 ? "" : "s") — nice"
        case .overloadedFixed:
            return flexPlaced > 0
                ? "I've placed your \(flexPlaced) flex event\(flexPlaced == 1 ? "" : "s") in the lighter spots"
                : "Most of this week is fixed — I've mapped the load so you can see it clearly"
        case .patternLearner:
            return "Energy spread across \(activeDays) day\(activeDays == 1 ? "" : "s") — your patterns helped"
        }
    }

    // MARK: - Ember card

    private var emberCard: some View {
        HStack(spacing: 14) {
            // Ember avatar — warm glow behind, amber border ring
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NimvaColors.amberWarm.opacity(0.3), .clear],
                            center: .center, startRadius: 0, endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 56)

                EmberView(expression: emberExpression, size: .mini)
                    .frame(width: 44, height: 44)
                    .background(NimvaColors.cardDark)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NimvaColors.amberWarm, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(emberMoodLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NimvaColors.textPrimary)
                Text(emberNote)
                    .font(.system(size: 11))
                    .foregroundStyle(NimvaColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.3), value: genState)
    }

    private var emberExpression: EmberExpression {
        switch genState {
        case .ready:    return .calm
        case .building: return .thinking
        case .done:     return .happy
        }
    }

    private var emberMoodLabel: String {
        switch genState {
        case .ready:    return "Ready when you are"
        case .building: return "Finding the best slots..."
        case .done:
            switch userType {
            case .optimizer:      return "Looks like a solid week"
            case .overloadedFixed: return "Heavy week — I've worked around your fixed load"
            case .patternLearner: return "Good mix — your patterns helped guide this"
            }
        }
    }

    private var emberNote: String {
        switch genState {
        case .ready:
            let n = flexibleEvents.count
            return n == 0 ? "Add flexible events first" : "\(n) flexible event\(n == 1 ? "" : "s") to place"
        case .building:
            return "Working through your energy load..."
        case .done:
            switch userType {
            case .optimizer, .patternLearner:
                guard let score = schedule?.balanceScore else { return "Your week is ready to approve" }
                return "Balance score: \(Int(score * 100))%"
            case .overloadedFixed:
                let flexPlaced = schedule?.placedFlexibleEvents.count ?? 0
                return flexPlaced > 0
                    ? "Flex time placed in the lighter spots — approve when ready"
                    : "Week mapped — knowing the load is the first step"
            }
        }
    }

    // MARK: - Progress bar

    private var energyProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NimvaColors.purpleMuted)
                        .frame(height: 6)

                    // Gradient bar — teal → purple → amber mirrors the energy bar on Home
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [NimvaColors.teal, NimvaColors.purplePrimary, NimvaColors.amber],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text(genState == .done ? "Energy balance" : "Progress")
                    .font(.system(size: 10))
                    .foregroundStyle(NimvaColors.textMuted)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NimvaColors.textSecondary)
            }
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionArea: some View {
        switch genState {
        case .ready:
            Button(action: startBuilding) {
                Label("Build my week", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(events.isEmpty ? NimvaColors.purplePrimary.opacity(0.4) : NimvaColors.purplePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(events.isEmpty)

        case .building:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text("Building...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(NimvaColors.purplePrimary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))

        case .done:
            VStack(spacing: 12) {
                Button(action: approveWeek) {
                    Text("Approve week")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NimvaColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: redo) {
                    Text("Redo")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NimvaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NimvaColors.cardDark)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(NimvaColors.border, lineWidth: 1)
                        )
                }
            }
        }
    }

    // MARK: - Actions

    private func startBuilding() {
        do {
            try SchedulerService.regenerate(context: modelContext, events: events)
            schedule = try SchedulerService.loadCachedSchedule(context: modelContext, events: events)
        } catch {
            showingScheduleError = true
            return
        }

        withAnimation { genState = .building }
        revealedDays = []

        // Animate each day's events dropping in, left to right, ~0.3s apart
        let days = DayOfWeek.allCases
        for (i, day) in days.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    revealedDays.insert(day)
                    progress = Double(i + 1) / Double(days.count)
                }
            }
        }

        // Transition to done after all days have been revealed
        let finishDelay = Double(days.count) * 0.3 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
            withAnimation(.easeInOut(duration: 0.4)) {
                genState = .done
                // Show balance score on the progress bar
                progress = schedule?.balanceScore ?? progress
            }
        }
    }

    // Week is already saved in SwiftData by SchedulerService.regenerate — just navigate away.
    // For now we reset to .ready so the screen can be reused; the tab bar will route home.
    private func approveWeek() {
        withAnimation { genState = .ready; progress = 0 }
    }

    private func redo() {
        withAnimation {
            genState = .ready
            schedule = nil
            revealedDays = []
            progress = 0
        }
    }
}

// MARK: - GenDayColumn
// One column in the day grid. Shows fixed events as purple bars and placed
// flexible events as teal bars that animate in during the building phase.

private struct GenDayColumn: View {
    let day: DayOfWeek
    let fixedEvents: [Event]
    let placedFlexible: [Event]
    let showFlexible: Bool
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(day.shortName.uppercased())
                .font(.system(size: isCompact ? 8 : 10, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .lineLimit(1)

            VStack(spacing: 3) {
                ForEach(fixedEvents) { event in
                    eventBar(name: event.name, color: NimvaColors.purplePrimary)
                }

                if showFlexible {
                    ForEach(placedFlexible) { event in
                        eventBar(name: event.name, color: NimvaColors.teal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: isCompact ? 48 : 72, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func eventBar(name: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 10 : 14)
            .overlay(
                // Only show the name label in the expanded (non-compact) state
                Group {
                    if !isCompact {
                        Text(name)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 3)
                    }
                }
            )
    }
}

// MARK: - EventChip
// Compact pill shown in the "To schedule" section before the algorithm runs.

private struct EventChip: View {
    let event: Event

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(NimvaColors.teal)
                .frame(width: 6, height: 6)
            Text(event.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NimvaColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NimvaColors.teal.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(NimvaColors.teal.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - StatusChip
// Amber (warning) or teal (positive) chip shown after generation is done.

private struct StatusChip: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(NimvaColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    WeekGenerationView()
        .modelContainer(for: [Event.self, WeekCache.self], inMemory: true)
}
