import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // @Query keeps events and the cache live — any mutation elsewhere auto-updates these
    @Query(sort: \Event.createdAt) private var events: [Event]
    @Query private var caches: [WeekCache]

    // Set to true by OnboardingView when the user taps "Add my first event"
    @AppStorage("openAddEventOnLaunch") private var openAddEventOnLaunch = false

    @State private var selectedDay: DayOfWeek = Self.todayDayOfWeek()
    @State private var showingAddEvent = false
    @State private var showingCheckIn = false
    @State private var eventToEdit: Event?
    @State private var showingScheduleError = false

    // Convenience accessor — at most one cache entry exists at a time
    private var cache: WeekCache? { caches.first }

    // Loads per day from the current cache (fallback: all zeros)
    private var dailyLoads: [DayOfWeek: Double] {
        guard let cache else {
            return Dictionary(uniqueKeysWithValues: DayOfWeek.allCases.map { ($0, 0.0) })
        }
        // Recompute loads from cache placements + fixed events
        var loads: [DayOfWeek: Double] = Dictionary(
            uniqueKeysWithValues: DayOfWeek.allCases.map { ($0, 0.0) }
        )
        for event in events where event.isFixed {
            if let day = event.fixedDay { loads[day, default: 0] += event.energyCost }
        }
        if let data = cache.placementsJSON.data(using: .utf8),
           let records = try? JSONDecoder().decode([FlexRecord].self, from: data) {
            for record in records {
                if let day = DayOfWeek(rawValue: record.dayRawValue),
                   let event = events.first(where: { $0.id == record.eventId }) {
                    loads[day, default: 0] += event.energyCost
                }
            }
        }
        return loads
    }

    private var heavyDays: Set<DayOfWeek> {
        Set((cache?.heavyDayValues ?? []).compactMap { DayOfWeek(rawValue: $0) })
    }

    private var eventsForSelectedDay: [Event] {
        guard let cache else { return events.filter { $0.isFixed && $0.fixedDay == selectedDay } }
        return SchedulerService.events(for: selectedDay, cache: cache, from: events)
    }

    private var overflowCount: Int {
        guard let cache else { return 0 }
        let flexTotal = events.filter { !$0.isFixed }.count
        return SchedulerService.overflowCount(cache: cache, totalFlexible: flexTotal)
    }

    private var userType: UserType {
        SchedulerService.detectUserType(events: events)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NimvaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ── Greeting ──
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greetingText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NimvaColors.textMuted)
                                .textCase(.uppercase)
                                .kerning(0.6)
                            Text("Your week")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(NimvaColors.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // ── Week strip ──
                    WeekStripView(selectedDay: $selectedDay, dailyLoads: dailyLoads)
                        .padding(.horizontal, 12)

                    // ── Energy zone card ──
                    EnergyZoneCard(
                        selectedDay: selectedDay,
                        dailyLoads: dailyLoads,
                        heavyDays: heavyDays,
                        eventsOnSelectedDay: eventsForSelectedDay.count,
                        overflowCount: overflowCount,
                        userType: userType
                    )
                    .padding(.horizontal, 20)

                    // ── Check-in banner ──
                    // Shown only when a week has been generated but not yet checked in.
                    // Disappears automatically once checkInRating is set.
                    if let cache, cache.checkInRating == nil {
                        Button { showingCheckIn = true } label: {
                            HStack(spacing: 12) {
                                Text("😌")
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("How did this week feel?")
                                        .font(NimvaFont.cardTitle)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text("Check in — takes about a minute")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(NimvaColors.textMuted)
                            }
                            .padding(14)
                            .background(NimvaColors.cardDark)
                            .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .sheet(isPresented: $showingCheckIn) {
                            WeeklyCheckInView(cache: cache, onDismiss: { showingCheckIn = false })
                        }
                    }

                    // ── Day event list ──
                    VStack(spacing: 0) {
                        HStack {
                            Text(selectedDay.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(NimvaColors.textMuted)
                                .textCase(.uppercase)
                                .kerning(0.7)
                                .contentTransition(.opacity)
                            Spacer()
                            Text("\(eventsForSelectedDay.count) events")
                                .font(.system(size: 10))
                                .foregroundStyle(NimvaColors.textMuted)
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        .nimvaAnimation(NimvaAnimation.stateChange, value: selectedDay)

                        if eventsForSelectedDay.isEmpty {
                            VStack(spacing: 8) {
                                Text("Nothing scheduled")
                                    .font(.system(size: 14))
                                    .foregroundStyle(NimvaColors.textMuted)
                                Text("Tap + to add an event")
                                    .font(.system(size: 12))
                                    .foregroundStyle(NimvaColors.textMuted.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(eventsForSelectedDay) { event in
                                    EventCard(event: event)
                                        .pressScale()
                                        .padding(.horizontal, 20)
                                        .onTapGesture { eventToEdit = event }
                                }
                            }
                        }
                    }
                    .nimvaAnimation(NimvaAnimation.stateChange, value: selectedDay)

                    // Bottom padding so the FAB doesn't cover the last event
                    Spacer(minLength: 80)
                }
                .padding(.top, 16)
            }

            // ── Floating add button ──
            Button {
                NimvaHaptics.medium()
                showingAddEvent = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(NimvaColors.purplePrimary)
                    .clipShape(Circle())
                    .shadow(color: NimvaColors.purplePrimary.opacity(0.5), radius: 12, x: 0, y: 4)
            }
            .pressScale()
            .padding(24)
        }
        .sheet(isPresented: $showingAddEvent, onDismiss: recomputeSchedule) {
            AddEventView()
        }
        .sheet(item: $eventToEdit, onDismiss: recomputeSchedule) { event in
            EditEventView(event: event)
        }
        .onAppear {
            // If the user tapped "Add my first event" at the end of onboarding, open the sheet now
            if openAddEventOnLaunch {
                openAddEventOnLaunch = false
                showingAddEvent = true
            }
            // Seed the cache on first launch if events exist but no cache has been built yet
            if cache == nil && !events.isEmpty {
                recomputeSchedule()
            }
        }
        .alert("Couldn't update your schedule", isPresented: $showingScheduleError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Something went wrong saving your week. Try again or restart the app if the problem persists.")
        }
    }

    // MARK: - Helpers

    func recomputeSchedule() {
        do {
            try SchedulerService.regenerate(context: modelContext, events: events)
        } catch {
            showingScheduleError = true
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // Maps today's Calendar weekday to our DayOfWeek enum.
    // Calendar.weekday: 1=Sunday, 2=Monday … 7=Saturday
    // DayOfWeek.rawValue: 1=Monday … 7=Sunday
    static func todayDayOfWeek() -> DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Shift Sunday (1) to 7, everything else down by 1
        let raw = weekday == 1 ? 7 : weekday - 1
        return DayOfWeek(rawValue: raw) ?? .monday
    }
}

// MARK: - FlexRecord (mirrors SchedulerService's private PlacementRecord for local decoding)

// We decode the placements JSON directly here so HomeView doesn't need SchedulerService
// to expose its private PlacementRecord type.
private struct FlexRecord: Decodable {
    let eventId: UUID
    let dayRawValue: Int
}

// MARK: - EventCard

private struct EventCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            // Color dot — purple for fixed, teal for flexible
            Circle()
                .fill(event.isFixed ? NimvaColors.purplePrimary : NimvaColors.teal)
                .frame(width: 8, height: 8)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NimvaColors.textPrimary)

                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundStyle(NimvaColors.textSecondary)
            }

            Spacer()

            // Energy badge
            Text(energyLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(energyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(energyColor.opacity(0.12))
                .clipShape(Capsule())

            // Type tag
            Text(event.isFixed ? "Fixed" : "Flex")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(NimvaColors.textMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(NimvaColors.purpleMuted.opacity(0.5))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }

    private var subtitleText: String {
        if event.isFixed {
            if let start = event.startTime, let end = event.endTime {
                let fmt = DateFormatter(); fmt.timeStyle = .short
                return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
            }
            return event.fixedDay?.displayName ?? ""
        } else {
            let window = event.preferredWindow?.displayName ?? "Any time"
            if let dur = event.duration {
                let mins = Int(dur / 60)
                let h = mins / 60; let m = mins % 60
                let s = h == 0 ? "\(m)m" : (m == 0 ? "\(h)h" : "\(h)h \(m)m")
                return "\(window) · \(s)"
            }
            return window
        }
    }

    private var energyLabel: String {
        EnergyLabel.allCases
            .min(by: { abs($0.cost - event.energyCost) < abs($1.cost - event.energyCost) })?
            .displayName ?? "–"
    }

    private var energyColor: Color {
        switch event.energyCost {
        case ..<0.35: return NimvaColors.teal
        case ..<0.6:  return NimvaColors.amber
        case ..<0.85: return NimvaColors.coral
        default:      return NimvaColors.coral
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Event.self, WeekCache.self], inMemory: true)
}
