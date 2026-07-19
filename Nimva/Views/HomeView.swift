import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // @Query keeps events and the cache live — any mutation elsewhere auto-updates these
    @Query(sort: \Event.createdAt) private var events: [Event]
    @Query(sort: \WeekCache.weekStartDate, order: .reverse) private var caches: [WeekCache]
    @Query(sort: \Intention.createdAt) private var allIntentions: [Intention]

    // Set to true by OnboardingView when the user taps "Add my first event"
    @AppStorage("openAddEventOnLaunch") private var openAddEventOnLaunch = false

    @AppStorage("displayName") private var displayName = "Your Name"
    @AppStorage("selectedTab") private var selectedTab = 0

    @State private var selectedDay: DayOfWeek = Self.todayDayOfWeek()
    @State private var showingAddEvent = false
    @State private var showingCheckIn = false
    @State private var eventToEdit: Event?
    @State private var showingScheduleError = false
    @State private var contentAppeared = false
    @State private var undoSnapshot: DeletedEventSnapshot? = nil
    @State private var showUndoBanner = false
    @State private var undoTask: Task<Void, Never>? = nil
    @State private var showingAddIntention = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        let raw: [Event]
        if let cache {
            raw = SchedulerService.events(for: selectedDay, cache: cache, from: events)
        } else {
            raw = events.filter { $0.isFixed && $0.fixedDay == selectedDay }
        }
        // Fixed events sort by start time; flex events (no startTime) fall to the end.
        return raw.sorted { a, b in
            switch (a.startTime, b.startTime) {
            case (.some(let at), .some(let bt)): return at < bt
            case (.some, .none):                 return true
            case (.none, .some):                 return false
            case (.none, .none):                 return false
            }
        }
    }

    private var completedEventIds: Set<UUID> {
        guard let cache,
              let data = cache.completedEventIdsJSON.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    // The first non-completed event on today's list — nil when viewing a different day.
    private var nextUpEventId: UUID? {
        guard selectedDay == Self.todayDayOfWeek() else { return nil }
        return eventsForSelectedDay.first { !completedEventIds.contains($0.id) }?.id
    }

    private func nextUpLabel(for event: Event) -> String? {
        guard event.id == nextUpEventId else { return nil }
        let now = Date()
        if let start = event.startTime, let end = event.endTime, start <= now, now <= end {
            return "Now"
        }
        return "Next"
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

            if events.isEmpty {
                firstRunEmptyState
                    .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // ── Greeting ──
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(greetingText)
                                    .font(NimvaFont.chip)
                                    .foregroundStyle(NimvaColors.textMuted)
                                    .textCase(.uppercase)
                                    .kerning(0.6)
                                Text("Your week")
                                    .font(NimvaFont.greeting)
                                    .foregroundStyle(NimvaColors.textPrimary)
                                // #56: overloaded users get honest framing; others get the standard summary
                                if cache != nil {
                                    let subtitle = weekSubtitle
                                    if !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.system(.caption))
                                            .foregroundStyle(NimvaColors.textMuted)
                                            .transition(.opacity)
                                    }
                                }
                                // #59: lightest upcoming day — only when viewing today
                                if cache != nil {
                                    let lightestText = lightestDaySubtitle
                                    if !lightestText.isEmpty {
                                        Text(lightestText)
                                            .font(NimvaFont.micro)
                                            .foregroundStyle(NimvaColors.textMuted.opacity(0.75))
                                            .transition(.opacity)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // ── Week strip ──
                        WeekStripView(selectedDay: $selectedDay, dailyLoads: dailyLoads, today: Self.todayDayOfWeek())
                            .padding(.horizontal, 12)

                        // ── Energy zone card ──
                        // Only shown after the first build — before that dailyLoads
                        // are all zeros and the card conveys nothing meaningful.
                        if cache != nil {
                            EnergyZoneCard(
                                selectedDay: selectedDay,
                                dailyLoads: dailyLoads,
                                heavyDays: heavyDays,
                                eventsOnSelectedDay: eventsForSelectedDay.count,
                                overflowCount: overflowCount,
                                userType: userType,
                                isRecoveryWeek: cache?.wasRecoveryWeek == true
                            )
                            .padding(.horizontal, 20)
                        }

                        // ── Ember daily note ──
                        // Only appears when IntelligenceService has something timing-specific
                        // to say that EnergyZoneCard's generic load narrative doesn't cover.
                        if cache != nil {
                            let note = IntelligenceService.dailyNote(events: eventsForSelectedDay)
                            if !note.isEmpty {
                                HStack(spacing: 12) {
                                    EmberView(expression: .calm, size: .mini)
                                        .frame(width: 28, height: 28)
                                    Text(note)
                                        .font(.system(.caption))
                                        .foregroundStyle(NimvaColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(14)
                                .background(NimvaColors.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 20)
                                .id(selectedDay)
                                .transition(.opacity.combined(with: .offset(y: 4)))
                                .nimvaAnimation(NimvaAnimation.cardAppear, value: selectedDay)
                            }
                        }

                        // ── Forward warning card (#57) ──
                        // Count-specific warning about tomorrow — only shown when viewing today
                        // and tomorrow has ≥3 draining events. EnergyZoneCard's dayNote
                        // already covers the generic "tomorrow looks heavy" framing.
                        if let cache {
                            let warning = forwardWarningText(cache: cache)
                            if !warning.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(NimvaFont.body)
                                        .foregroundStyle(NimvaColors.amber)
                                        .frame(width: 28, height: 28)
                                    Text(warning)
                                        .font(.system(.caption))
                                        .foregroundStyle(NimvaColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(14)
                                .background(NimvaColors.cardDark)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(NimvaColors.amber.opacity(0.25), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .offset(y: 4)))
                            }
                        }

                        // ── Nudge card ──
                        // Before first build: guide the user toward adding enough events,
                        // then toward actually building — revealed progressively.
                        if cache == nil {
                            if events.count < 3 {
                                let remaining = 3 - events.count
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.purplePrimary)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Keep going")
                                            .font(NimvaFont.cardTitle)
                                            .foregroundStyle(NimvaColors.textPrimary)
                                        Text("Add \(remaining) more event\(remaining == 1 ? "" : "s") and Nimva will be ready to build your week")
                                            .font(NimvaFont.micro)
                                            .foregroundStyle(NimvaColors.textMuted)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(NimvaColors.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
                                .padding(.horizontal, 20)
                            } else {
                                Button { selectedTab = 1 } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "sparkles")
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(NimvaColors.teal)
                                            .frame(width: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Ready to build your week?")
                                                .font(NimvaFont.cardTitle)
                                                .foregroundStyle(NimvaColors.textPrimary)
                                            Text("Tap to go to the Plan tab")
                                                .font(NimvaFont.micro)
                                                .foregroundStyle(NimvaColors.textMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(NimvaFont.sectionLabel)
                                            .foregroundStyle(NimvaColors.textMuted)
                                    }
                                    .padding(14)
                                    .background(NimvaColors.cardDark)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: NimvaLayout.cardRadius)
                                            .stroke(NimvaColors.teal.opacity(0.3), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }
                        }

                        // ── Check-in banner ──
                        // Shown only when a week has been generated but not yet checked in.
                        if let cache, cache.checkInRating == nil {
                            Button { showingCheckIn = true } label: {
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(NimvaColors.teal)
                                        .frame(width: 3)
                                    HStack(spacing: 12) {
                                        EmberView(expression: .calm, size: .mini)
                                            .frame(width: 32, height: 32)
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
                                            .font(NimvaFont.sectionLabel)
                                            .foregroundStyle(NimvaColors.textMuted)
                                    }
                                    .padding(14)
                                }
                                .background(NimvaColors.cardDark)
                                .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .sheet(isPresented: $showingCheckIn) {
                                WeeklyCheckInView(cache: cache, onDismiss: { showingCheckIn = false })
                            }
                        }

                        // ── Intentions (light week mode) ──
                        // When the week is open, shift from optimizer to intention anchor.
                        if cache != nil && isLightWeek {
                            Group {
                                if currentWeekIntentions.isEmpty {
                                    intentionsPromptCard
                                } else {
                                    intentionsListCard
                                }
                            }
                            .transition(.opacity.combined(with: .offset(y: 6)))
                            .animation(reduceMotion ? .none : NimvaAnimation.cardAppear, value: currentWeekIntentions.isEmpty)
                        }

                        // ── Energy experiment (light week mode) ──
                        // One small behavioral nudge per light week, suggested by Nimva.
                        if let experiment = cache?.experimentText, cache?.wasRecoveryWeek == true {
                            experimentCard(text: experiment)
                                .transition(.opacity.combined(with: .offset(y: 6)))
                        }

                        // ── Day event list ──
                        VStack(spacing: 0) {
                            HStack {
                                Text(selectedDay.displayName)
                                    .font(NimvaFont.chip)
                                    .foregroundStyle(NimvaColors.textMuted)
                                    .textCase(.uppercase)
                                    .kerning(0.7)
                                    .contentTransition(.opacity)
                                Spacer()
                                Text("\(eventsForSelectedDay.count) event\(eventsForSelectedDay.count == 1 ? "" : "s")")
                                    .font(NimvaFont.micro)
                                    .foregroundStyle(NimvaColors.textMuted)
                                    .contentTransition(.numericText())
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                            .nimvaAnimation(NimvaAnimation.stateChange, value: selectedDay)

                            Group {
                                if eventsForSelectedDay.isEmpty {
                                    VStack(spacing: 6) {
                                        Text(emptyDayMessage.headline)
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(NimvaColors.textMuted)
                                        Text(emptyDayMessage.sub)
                                            .font(.system(.caption))
                                            .foregroundStyle(NimvaColors.textMuted.opacity(0.6))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(Array(eventsForSelectedDay.enumerated()), id: \.element.id) { index, event in
                                            EventCard(
                                                event: event,
                                                index: index,
                                                placementReason: placementReasons[event.id],
                                                isCompleted: completedEventIds.contains(event.id),
                                                nextUpLabel: nextUpLabel(for: event),
                                                onTap: { eventToEdit = event },
                                                onCheckmark: { toggleCompletion(event) }
                                            )
                                                .id("\(selectedDay.rawValue)-\(event.id)")
                                                .padding(.horizontal, 20)
                                                .contextMenu {
                                                    Button { eventToEdit = event } label: {
                                                        Label("Edit", systemImage: "pencil")
                                                    }
                                                    Button(role: .destructive) { deleteEvent(event) } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            .id(selectedDay)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 8)),
                                removal: .opacity
                            ))
                            .nimvaAnimation(NimvaAnimation.cardAppear, value: selectedDay)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        let h = value.translation.width
                                        let v = value.translation.height
                                        guard abs(h) > abs(v) * 1.5, abs(h) > 50 else { return }
                                        swipeDay(by: h < 0 ? 1 : -1)
                                    }
                            )
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 16)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                }
                .transition(.opacity)
            }

            // ── Floating add button ──
            // Hidden in the empty state — the inline CTA button is the single action there.
            if !events.isEmpty {
                Button {
                    NimvaHaptics.medium()
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus")
                        .font(NimvaFont.pageTitle)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(NimvaColors.purplePrimary)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add event")
                .pressScale()
                .padding(24)
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoBanner {
                undoBannerView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(reduceMotion ? .none : NimvaAnimation.cardAppear, value: showUndoBanner)
        .animation(reduceMotion ? .none : NimvaAnimation.cardAppear, value: events.isEmpty)
        .sheet(isPresented: $showingAddEvent, onDismiss: recomputeSchedule) {
            AddEventView(defaultDay: selectedDay)
        }
        .sheet(item: $eventToEdit, onDismiss: recomputeSchedule) { event in
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddIntention) {
            AddIntentionView()
        }
        .onAppear {
            // Snap to today on initial load only — preserves intentional day selection
            // when the user switches tabs and returns, but corrects stale state on relaunch.
            if !contentAppeared {
                selectedDay = Self.todayDayOfWeek()
            }
            if openAddEventOnLaunch {
                openAddEventOnLaunch = false
                showingAddEvent = true
            }
            if cache == nil && !events.isEmpty {
                recomputeSchedule()
            }
            if !reduceMotion {
                withAnimation(NimvaAnimation.cardAppear.delay(0.08)) {
                    contentAppeared = true
                }
            } else {
                contentAppeared = true
            }
        }
        .alert("Couldn't update your schedule", isPresented: $showingScheduleError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Something went wrong saving your week. Try again or restart the app if the problem persists.")
        }
    }

    // MARK: - Intentions

    private var isLightWeek: Bool {
        SchedulerService.isLightWeek(events: events)
    }

    private var currentWeekIntentions: [Intention] {
        let weekStart = SchedulerService.weekStart()
        return allIntentions.filter {
            SchedulerService.mondayCal.isDate($0.weekOf, equalTo: weekStart, toGranularity: .weekOfYear)
        }
    }

    private var intentionsPromptCard: some View {
        let isRecovery = cache?.wasRecoveryWeek == true
        return Button { showingAddIntention = true } label: {
            HStack(spacing: 12) {
                EmberView(expression: isRecovery ? .calm : .happy, size: .mini)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRecovery ? "A lighter week" : "Your week looks open")
                        .font(NimvaFont.cardTitle)
                        .foregroundStyle(NimvaColors.textPrimary)
                    Text(isRecovery ? "A good window to actually rest — or do something low-stakes." : "Anything you'd like to do with this time?")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(NimvaFont.bodySemi)
                    .foregroundStyle(NimvaColors.teal)
            }
            .padding(14)
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel(isRecovery ? "A lighter week. Tap to add an intention." : "Your week looks open. Tap to add an intention.")
        .accessibilityAddTraits(.isButton)
    }

    private var intentionsListCard: some View {
        let isRecovery = cache?.wasRecoveryWeek == true
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week's intentions")
                        .font(NimvaFont.chip)
                        .foregroundStyle(NimvaColors.textMuted)
                        .textCase(.uppercase)
                        .kerning(0.7)
                    Text(isRecovery ? "A lighter week — open time to use how you want." : "Your week looks open.")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted.opacity(0.7))
                }
                Spacer()
                Button { showingAddIntention = true } label: {
                    Image(systemName: "plus")
                        .font(NimvaFont.bodySemi)
                        .foregroundStyle(NimvaColors.teal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add another intention")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            VStack(spacing: 8) {
                ForEach(currentWeekIntentions) { intention in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(NimvaColors.teal.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                            .accessibilityHidden(true)
                        Text(intention.text)
                            .font(NimvaFont.body)
                            .foregroundStyle(NimvaColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NimvaColors.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Intention: \(intention.text)")
                    .accessibilityHint("Hold to delete")
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteIntention(intention)
                        } label: {
                            Label("Delete intention", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func experimentCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flask")
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.amber)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week's experiment")
                        .font(NimvaFont.chip)
                        .foregroundStyle(NimvaColors.textMuted)
                        .textCase(.uppercase)
                        .kerning(0.6)
                    Text(text)
                        .font(NimvaFont.body)
                        .foregroundStyle(NimvaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("A small thing to try. Notice if it changes anything.")
                .font(NimvaFont.micro)
                .foregroundStyle(NimvaColors.textMuted.opacity(0.75))
        }
        .padding(14)
        .background(NimvaColors.cardDark)
        .overlay(
            RoundedRectangle(cornerRadius: NimvaLayout.cardRadius)
                .stroke(NimvaColors.amber.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: NimvaLayout.cardRadius))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week's experiment: \(text)")
    }

    // MARK: - Helpers

    func recomputeSchedule() {
        do {
            try SchedulerService.regenerate(context: modelContext, events: events)
        } catch {
            showingScheduleError = true
        }
    }

    private func deleteEvent(_ event: Event) {
        undoSnapshot = DeletedEventSnapshot(from: event)
        modelContext.delete(event)
        recomputeSchedule()
        undoTask?.cancel()
        withAnimation(NimvaAnimation.cardAppear) { showUndoBanner = true }
        undoTask = Task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(NimvaAnimation.stateChange) { showUndoBanner = false }
                undoSnapshot = nil
            }
        }
    }

    private func toggleCompletion(_ event: Event) {
        guard let cache else { return }
        var ids = completedEventIds
        if ids.contains(event.id) {
            ids.remove(event.id)
            NimvaHaptics.light()
        } else {
            ids.insert(event.id)
            NimvaHaptics.success()
        }
        if let data = try? JSONEncoder().encode(ids.map { $0.uuidString }),
           let json = String(data: data, encoding: .utf8) {
            cache.completedEventIdsJSON = json
            try? modelContext.save()
        }
    }

    private func deleteIntention(_ intention: Intention) {
        modelContext.delete(intention)
        try? modelContext.save()
    }

    private func undoDelete() {
        guard let snap = undoSnapshot else { return }
        undoTask?.cancel()
        modelContext.insert(snap.recreate())
        recomputeSchedule()
        withAnimation(NimvaAnimation.stateChange) { showUndoBanner = false }
        undoSnapshot = nil
    }

    private func swipeDay(by offset: Int) {
        let days = DayOfWeek.orderedForLocale
        guard let idx = days.firstIndex(of: selectedDay) else { return }
        let newIdx = idx + offset
        guard days.indices.contains(newIdx) else { return }
        NimvaHaptics.selection()
        withAnimation(NimvaAnimation.stateChange) { selectedDay = days[newIdx] }
    }

    // Map of flexible event UUID → placement reason, decoded once per cache (#62)
    private var placementReasons: [UUID: String] {
        guard let cache else { return [:] }
        return SchedulerService.placementReasons(in: cache)
    }

    // #56: overloaded users get honest fixed-week framing; everyone else gets load summary
    private var weekSubtitle: String {
        if userType == .overloadedFixed {
            return IntelligenceService.overloadedWeekNote(dailyLoads: dailyLoads)
        }
        return IntelligenceService.weekLoadSummary(dailyLoads: dailyLoads)
    }

    // #59: lightest upcoming day — only surfaced when viewing today and a lighter day exists ahead
    private var lightestDaySubtitle: String {
        let today = Self.todayDayOfWeek()
        guard selectedDay == today,
              let lightest = IntelligenceService.lightestUpcomingDay(dailyLoads: dailyLoads, from: today),
              lightest != today
        else { return "" }
        return "\(lightest.displayName) looks like your lightest day."
    }

    // #57: count-specific forward warning — only when viewing today and tomorrow is heavily draining
    private func forwardWarningText(cache: WeekCache) -> String {
        let today = Self.todayDayOfWeek()
        guard selectedDay == today, let tomorrow = today.next else { return "" }
        let tomorrowEvents = SchedulerService.events(for: tomorrow, cache: cache, from: events)
        let drainingCount = tomorrowEvents.filter { $0.energyCost > 0.5 }.count
        return IntelligenceService.forwardWarning(today: today, tomorrowDrainingCount: drainingCount)
    }

    private var emptyDayMessage: (headline: String, sub: String) {
        let today = Self.todayDayOfWeek()
        let isToday = selectedDay == today
        let isWeekend = selectedDay == .saturday || selectedDay == .sunday
        let days = DayOfWeek.orderedForLocale
        let prevDayHeavy: Bool = {
            guard let idx = days.firstIndex(of: selectedDay), idx > 0 else { return false }
            return heavyDays.contains(days[idx - 1])
        }()

        if isWeekend {
            return ("A day off.", "Hold onto it.")
        } else if prevDayHeavy && isToday {
            return ("Light day after a tough one.", "Protect this space.")
        } else if isToday {
            return ("Open space today.", "A good thing.")
        } else {
            return ("Nothing here.", "Protect this gap.")
        }
    }

    private var undoBannerView: some View {
        HStack {
            Text("Event deleted")
                .font(NimvaFont.bodyMedium)
                .foregroundStyle(NimvaColors.textSecondary)
            Spacer()
            Button("Undo") { undoDelete() }
                .font(NimvaFont.bodySemi)
                .foregroundStyle(NimvaColors.teal)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NimvaColors.border, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 96)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12:  base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default:      base = "Good evening"
        }
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != "Your Name" else { return base }
        return "\(base), \(name)"
    }

    private var firstRunEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            EmberView(expression: .calm, size: .standard)
                .frame(width: 120, height: 120)
                .opacity(contentAppeared ? 1 : 0)
                .scaleEffect(contentAppeared ? 1 : 0.85)
                .nimvaAnimation(NimvaAnimation.squashStretch, value: contentAppeared)
            VStack(spacing: 8) {
                Text("Let's build your week")
                    .font(NimvaFont.pageTitle)
                    .foregroundStyle(NimvaColors.textPrimary)
                Text("Tag your events by how much energy they take — Nimva schedules around that.")
                    .font(NimvaFont.callout)
                    .foregroundStyle(NimvaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 8)
            .nimvaAnimation(NimvaAnimation.cardAppear.delay(0.15), value: contentAppeared)

            Button {
                showingAddEvent = true
            } label: {
                Text("Add your first event")
                    .font(NimvaFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NimvaColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .opacity(contentAppeared ? 1 : 0)
            .nimvaAnimation(NimvaAnimation.cardAppear.delay(0.25), value: contentAppeared)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            if reduceMotion {
                contentAppeared = true
            } else {
                withAnimation(NimvaAnimation.cardAppear.delay(0.1)) {
                    contentAppeared = true
                }
            }
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

// MARK: - DeletedEventSnapshot

private struct DeletedEventSnapshot {
    let name: String
    let isFixed: Bool
    let fixedDay: DayOfWeek?
    let startTime: Date?
    let endTime: Date?
    let preferredWindow: TimePreference?
    let duration: TimeInterval?
    let energyCost: Double
    let category: String
    let patternLearningEnabled: Bool
    let isRecurring: Bool
    let isPriority: Bool

    init(from event: Event) {
        name = event.name
        isFixed = event.isFixed
        fixedDay = event.fixedDay
        startTime = event.startTime
        endTime = event.endTime
        preferredWindow = event.preferredWindow
        duration = event.duration
        energyCost = event.energyCost
        category = event.category
        patternLearningEnabled = event.patternLearningEnabled
        isRecurring = event.isRecurring
        isPriority = event.isPriority
    }

    func recreate() -> Event {
        Event(
            name: name, isFixed: isFixed, fixedDay: fixedDay,
            startTime: startTime, endTime: endTime,
            preferredWindow: preferredWindow, duration: duration,
            energyCost: energyCost, category: category,
            patternLearningEnabled: patternLearningEnabled,
            isRecurring: isRecurring, isPriority: isPriority
        )
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
    var index: Int = 0
    var placementReason: String? = nil
    var isCompleted: Bool = false
    var nextUpLabel: String? = nil
    var onTap: (() -> Void)? = nil
    var onCheckmark: (() -> Void)? = nil

    @AppStorage("useAltEnergyPalette") private var useAltPalette = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        Button { onTap?() } label: {
            HStack(spacing: 0) {
                // Left accent bar — purple for fixed, teal for flexible
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.isFixed ? NimvaColors.purplePrimary : NimvaColors.teal)
                    .frame(width: 3)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.name)
                            .font(NimvaFont.bodyMedium)
                            .foregroundStyle(isCompleted ? NimvaColors.textMuted : NimvaColors.textPrimary)
                            .strikethrough(isCompleted, color: NimvaColors.textMuted)
                        Text(subtitleText)
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textSecondary)
                        if let reason = placementReason, !event.isFixed {
                            Text(reason)
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)
                        }
                    }

                    Spacer()

                    // "Now" / "Next" pill — only on today's first uncompleted event
                    if let label = nextUpLabel {
                        Text(label)
                            .font(NimvaFont.chip)
                            .foregroundStyle(NimvaColors.teal)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(NimvaColors.teal.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Energy badge
                    Text(energyLabel)
                        .font(NimvaFont.chip)
                        .foregroundStyle(energyColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(energyColor.opacity(0.12))
                        .clipShape(Capsule())

                    // Type tag — "Must do" with amber tint for priority flex events
                    Text(typeTagLabel)
                        .font(NimvaFont.chip)
                        .foregroundStyle(typeTagColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(typeTagBackground)
                        .clipShape(Capsule())

                    // Checkmark — nested Button intercepts its own tap, outer Button handles edit
                    Button {
                        onCheckmark?()
                    } label: {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(.title3))
                            .foregroundStyle(isCompleted ? NimvaColors.teal : NimvaColors.border)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isCompleted ? "Completed. Tap to undo." : "Mark complete")
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 6)
            }
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(EventCardStyle(reduceMotion: reduceMotion))
        .opacity(isCompleted ? 0.6 : 1.0)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Tap to edit")
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
        .onAppear {
            if reduceMotion {
                visible = true
            } else {
                withAnimation(NimvaAnimation.cardAppear.delay(Double(index) * 0.06)) {
                    visible = true
                }
            }
        }
    }

    private var cardAccessibilityLabel: String {
        let base = "\(event.name), \(typeTagLabel), \(energyLabel) energy, \(subtitleText)"
        return isCompleted ? "Completed: \(base)" : base
    }

    private var typeTagLabel: String {
        if event.isFixed { return "Fixed" }
        return event.isPriority ? "Must do" : "Flex"
    }

    private var typeTagColor: Color {
        !event.isFixed && event.isPriority ? NimvaColors.amber : NimvaColors.textMuted
    }

    private var typeTagBackground: Color {
        !event.isFixed && event.isPriority ? NimvaColors.amber.opacity(0.12) : NimvaColors.purpleMuted.opacity(0.5)
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
        case ..<0.35: return NimvaColors.energyLight(useAltPalette)
        case ..<0.6:  return NimvaColors.energyMixed(useAltPalette)
        default:      return NimvaColors.energyHeavy(useAltPalette)
        }
    }
}

// MARK: - EventCardStyle

// Replaces the external pressScale() modifier on EventCard.
// ButtonStyle.isPressed is the ScrollView-safe way to animate press state —
// DragGesture(minimumDistance: 0) inside simultaneousGesture can suppress
// tap recognition when nested inside a ScrollView.
private struct EventCardStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1.0)
            .opacity(configuration.isPressed && !reduceMotion ? 0.85 : 1.0)
            .animation(NimvaAnimation.buttonPress, value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Event.self, WeekCache.self], inMemory: true)
}
