import SwiftUI
import SwiftData

struct AddEventView: View {
    var defaultDay: DayOfWeek? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.createdAt) private var events: [Event]

    @State private var name: String = ""
    @State private var isFixed: Bool = true
    @State private var selectedDays: Set<DayOfWeek> = [.monday]
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var preferredWindow: TimePreference = .any
    @State private var durationMinutes: Int = 60
    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var energyCost: Double = EnergyLabel.manageable.cost
    @State private var isPriority: Bool = false
    // Default true — a new flexible event only applies to the current week unless the
    // user says otherwise, matching how most one-off tasks ("study for chemistry test")
    // outnumber genuine recurring habits. See hasRecurringPattern below for how a task
    // added 3 weeks running gets offered as recurring instead of needing this flipped manually.
    @State private var isThisWeekOnly: Bool = true
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true
    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @State private var category: String = "General"
    @State private var categorySuggestionHint: String? = nil
    @FocusState private var nameFieldFocused: Bool

    @State private var showingRecurringPrompt = false
    @State private var pendingRecurringEvent: Event? = nil
    @State private var showingAddCategory = false
    @State private var newCategoryText = ""
    // Collapsed by default — Priority/Repeats are occasional-use settings; the common
    // "add a quick event" path shouldn't have to scroll past them every time.
    @State private var showingAdvanced = false
    // Once the user taps a label directly, a later category change must not silently
    // override that explicit choice — only ever pre-fill before they've touched it.
    @State private var energyManuallySet = false

    // Due date (#95) — only meaningful alongside isThisWeekOnly, since a deadline is a
    // one-time calendar date (see SchedulerService.deadlineDay's doc comment): an "every
    // week" recurring event with a fixed due date would silently stop being constrained
    // after its first week, which would be confusing rather than helpful. Gated in the UI
    // rather than letting the user set an expectation the feature doesn't fulfill.
    @State private var hasDueDate = false
    @State private var dueDay: DayOfWeek = SchedulerService.todayAsDayOfWeek()
    // Splitting (#95's related ask) only makes sense once there's both a due date to spread
    // toward and enough duration to be worth spreading — gated behind hasDueDate and a
    // minimum duration in the view below, not here.
    @State private var wantsSplit = false
    @State private var splitSessionCount = 2

    // Candidate time windows (#79) — fixed-event-only, a genuinely different shape from
    // either the due-date/split fields above (flexible-only) or the single startTime/endTime
    // below: "this happens on Tuesday, but could be either of these two specific times."
    // Collapsed by default like the flexible Advanced section, for the same reason — most
    // fixed events never need this.
    @State private var showingFixedAdvanced = false
    @State private var hasCandidateWindows = false
    @State private var candidateWindows: [CandidateWindowDraft] = []

    // Built-in presets first, then any custom categories already in use across real events —
    // self-cleaning, since nothing separately persists a custom category once every event
    // using it is deleted. Always includes the currently-selected category so a just-typed
    // custom one shows up immediately, before it's attached to any saved event.
    private var categoryOptions: [String] {
        let custom = Set(events.map(\.category)).union([category]).subtracting(EventCategory.presets)
        return EventCategory.presets + custom.sorted()
    }

    // Shared by the Save button's disabled condition and saveEvent() itself, so "is this
    // candidate-window set actually usable" is answered the same way in both places —
    // previously computed inline only in saveEvent(), which let an invalid set (e.g. an
    // option whose end precedes its start) silently save using stale top-level start/end
    // time with no feedback, instead of being caught before Save was even reachable.
    private var validCandidateWindows: [CandidateWindowDraft] {
        candidateWindows.filter { $0.end > $0.start }
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Event type
                Section {
                    Picker("Event type", selection: $isFixed) {
                        Text("Fixed").tag(true)
                        Text("Flexible").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Name
                Section("Event name") {
                    TextField("What's the event?", text: $name)
                        .foregroundStyle(NimvaColors.textPrimary)
                        .focused($nameFieldFocused)
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Category
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .foregroundStyle(NimvaColors.textPrimary)
                    .onChange(of: category) { _, newCategory in
                        applyCategorySuggestion(for: newCategory)
                    }

                    Button {
                        newCategoryText = ""
                        showingAddCategory = true
                    } label: {
                        Label("Add a category", systemImage: "plus.circle")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.teal)
                    }
                    .frame(minHeight: 44)
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Timing
                if isFixed {
                    Section("Timing") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day")
                                .font(.subheadline)
                                .foregroundStyle(NimvaColors.textMuted)
                            HStack(spacing: 6) {
                                ForEach(DayOfWeek.orderedForLocale, id: \.self) { day in
                                    DayChip(
                                        label: String(day.shortName.prefix(2)),
                                        isSelected: selectedDays.contains(day),
                                        fullLabel: day.displayName
                                    ) {
                                        if selectedDays.contains(day) {
                                            if selectedDays.count > 1 { selectedDays.remove(day) }
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        TimeInputRow(label: "Start time", date: $startTime)
                        TimeInputRow(label: "End time",   date: $endTime)
                        if endTime <= startTime {
                            Text("End time must be after start time")
                                .font(.caption)
                                .foregroundStyle(NimvaColors.coral)
                        }
                    }
                    .listRowBackground(NimvaColors.cardDark)

                    // MARK: Advanced (fixed — candidate windows, #79)
                    Section {
                        DisclosureGroup(isExpanded: $showingFixedAdvanced) {
                            Toggle(isOn: Binding(
                                get: { hasCandidateWindows },
                                set: { newValue in
                                    hasCandidateWindows = newValue
                                    if newValue {
                                        // Seed with the time already entered above as option 1,
                                        // so turning this on never loses what they'd already
                                        // set — plus one blank second option to fill in.
                                        candidateWindows = [
                                            CandidateWindowDraft(start: startTime, end: endTime),
                                            CandidateWindowDraft(
                                                start: Calendar.current.date(byAdding: .hour, value: 6, to: startTime) ?? startTime,
                                                end: Calendar.current.date(byAdding: .hour, value: 6, to: endTime) ?? endTime
                                            )
                                        ]
                                    } else {
                                        // Clear on turn-off, not just leave stale — so turning
                                        // this back on later always reseeds from whatever the
                                        // top Start/End fields hold *then*, not whatever they
                                        // held during an earlier on/off cycle. Found during
                                        // hardening: without this, toggling off then editing
                                        // the top time fields then toggling back on silently
                                        // resurrected the pre-edit time as Option 1.
                                        candidateWindows = []
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Offer a few possible times")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text("Nimva picks whichever fits best once you build your week")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                            }
                            .tint(NimvaColors.teal)

                            if hasCandidateWindows {
                                ForEach($candidateWindows) { $window in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Option \((candidateWindows.firstIndex(where: { $0.id == window.id }) ?? 0) + 1)")
                                                .font(NimvaFont.calloutMed)
                                                .foregroundStyle(NimvaColors.textPrimary)
                                            Spacer()
                                            // At least 2 options or this feature means nothing —
                                            // no delete control once only 2 remain.
                                            if candidateWindows.count > 2 {
                                                Button {
                                                    candidateWindows.removeAll { $0.id == window.id }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundStyle(NimvaColors.coral)
                                                }
                                                .buttonStyle(.scalePress)
                                                .accessibilityLabel("Remove this option")
                                            }
                                        }
                                        TimeInputRow(label: "Start", date: $window.start)
                                        TimeInputRow(label: "End", date: $window.end)
                                        // Only the top-level Timing fields had this error
                                        // message — an individual option silently just
                                        // vanished from the saved set with no explanation.
                                        // Found while hardening this session's work.
                                        if window.end <= window.start {
                                            Text("End must be after start")
                                                .font(.caption)
                                                .foregroundStyle(NimvaColors.coral)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }

                                // "A small set" per the feature's own framing — capped rather
                                // than letting this grow into a scheduling mini-form.
                                if candidateWindows.count < 4 {
                                    Button {
                                        let last = candidateWindows.last
                                        let base = last?.start ?? startTime
                                        candidateWindows.append(CandidateWindowDraft(
                                            start: Calendar.current.date(byAdding: .hour, value: 1, to: base) ?? base,
                                            end: Calendar.current.date(byAdding: .hour, value: 1, to: last?.end ?? endTime) ?? endTime
                                        ))
                                    } label: {
                                        Label("Add another option", systemImage: "plus.circle")
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(NimvaColors.teal)
                                    }
                                    .buttonStyle(.scalePress)
                                    .frame(minHeight: 44)
                                }
                            }
                        } label: {
                            Label("Advanced", systemImage: "slider.horizontal.3")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textPrimary)
                        }
                        .tint(NimvaColors.textPrimary)
                    }
                    .listRowBackground(NimvaColors.cardDark)
                } else {
                    Section("Timing") {
                        Picker("Preferred window", selection: $preferredWindow) {
                            ForEach(TimePreference.allCases, id: \.self) { window in
                                Text(window.displayName).tag(window)
                            }
                        }
                        .foregroundStyle(NimvaColors.textPrimary)
                        Stepper(
                            value: $durationMinutes,
                            in: 15...480,
                            step: 15
                        ) {
                            Text("Duration: \(formattedDuration)")
                                .foregroundStyle(NimvaColors.textPrimary)
                        }
                    }
                    .listRowBackground(NimvaColors.cardDark)

                    Section {
                        Label(
                            "Nimva will find the best slot based on your energy load",
                            systemImage: "sparkles"
                        )
                        .font(.footnote)
                        .foregroundStyle(NimvaColors.textMuted)
                    }
                    .listRowBackground(NimvaColors.cardDark)

                    Section {
                        DisclosureGroup(isExpanded: $showingAdvanced) {
                            Toggle(isOn: $isPriority) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Must do this week")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text("Scheduled before other flexible events")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                            }
                            .tint(NimvaColors.amber)
                            .padding(.top, 4)

                            Toggle(isOn: Binding(
                                get: { !isThisWeekOnly },
                                set: { isThisWeekOnly = !$0 }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isThisWeekOnly ? "This week only" : "Every week")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text(isThisWeekOnly
                                        ? "Won't be included in future weeks"
                                        : "Included in every week you build")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                            }
                            .tint(NimvaColors.teal)

                            // Gated to isThisWeekOnly — see hasDueDate's doc comment for why
                            // a fixed calendar due date doesn't compose with "every week."
                            if isThisWeekOnly {
                                Divider().padding(.vertical, 2)

                                Toggle(isOn: $hasDueDate) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Due by a specific day")
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(NimvaColors.textPrimary)
                                        Text("Won't be placed any later than this day")
                                            .font(NimvaFont.micro)
                                            .foregroundStyle(NimvaColors.textMuted)
                                    }
                                }
                                .tint(NimvaColors.teal)
                                .onChange(of: hasDueDate) { _, newValue in
                                    if !newValue { wantsSplit = false }
                                }

                                if hasDueDate {
                                    Picker("Due by", selection: $dueDay) {
                                        ForEach(availableDueDays, id: \.self) { day in
                                            Text(day.displayName).tag(day)
                                        }
                                    }
                                    .foregroundStyle(NimvaColors.textPrimary)
                                    .onChange(of: dueDay) { _, _ in
                                        splitSessionCount = min(splitSessionCount, maxSplitSessions)
                                    }

                                    // Only worth offering once there's enough duration for
                                    // multiple sessions to make sense — a 30-minute worksheet
                                    // doesn't need spreading across days.
                                    if durationMinutes > 60 {
                                        Toggle(isOn: $wantsSplit) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Split across days")
                                                    .font(NimvaFont.callout)
                                                    .foregroundStyle(NimvaColors.textPrimary)
                                                Text("Break this into smaller sessions leading up to the due day")
                                                    .font(NimvaFont.micro)
                                                    .foregroundStyle(NimvaColors.textMuted)
                                            }
                                        }
                                        .tint(NimvaColors.teal)

                                        if wantsSplit {
                                            Stepper(
                                                value: $splitSessionCount,
                                                in: 2...maxSplitSessions
                                            ) {
                                                Text("\(splitSessionCount) sessions, about \(formatMinutes(durationMinutes / splitSessionCount)) each")
                                                    .foregroundStyle(NimvaColors.textPrimary)
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Advanced", systemImage: "slider.horizontal.3")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textPrimary)
                        }
                        .tint(NimvaColors.textPrimary)
                    }
                    .listRowBackground(NimvaColors.cardDark)
                }

                // MARK: Energy
                Section("Energy") {
                    if let hint = categorySuggestionHint {
                        Label(hint, systemImage: "sparkles")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    EnergyLabelPicker(
                        selectedLabel: $selectedLabel,
                        energyCost: $energyCost,
                        onSelect: { energyManuallySet = true },
                        anchorLabel: energyAnchorLabel
                    )
                }
                .listRowBackground(NimvaColors.cardDark)
            }
            // Each conditionally-revealed section (Fixed↔Flexible swap, due-date fields,
            // split fields) gets its own value-keyed animation rather than one blanket
            // `.animation(_:)` on the Form — that would also catch every keystroke in the
            // name field and re-trigger the spring on every character typed, which reads as
            // jittery rather than dynamic. Keying to specific values means only an actual
            // state change animates.
            .nimvaAnimation(NimvaAnimation.transition, value: isFixed)
            .nimvaAnimation(NimvaAnimation.transition, value: hasDueDate)
            .nimvaAnimation(NimvaAnimation.transition, value: wantsSplit)
            .nimvaAnimation(NimvaAnimation.transition, value: categorySuggestionHint)
            .nimvaAnimation(NimvaAnimation.transition, value: hasCandidateWindows)
            .nimvaAnimation(NimvaAnimation.cardAppear, value: candidateWindows.count)
            .scrollContentBackground(.hidden)
            .background(NimvaColors.background)
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .tint(NimvaColors.purplePrimary)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFieldFocused = false }
                        .foregroundStyle(NimvaColors.purplePrimary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NimvaColors.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to week") { saveEvent() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  (isFixed && endTime <= startTime) ||
                                  (isFixed && hasCandidateWindows && validCandidateWindows.count < 2))
                }
            }
            .onAppear {
                if let day = defaultDay {
                    selectedDays = [day]
                }
            }
            .alert("Make this recurring?", isPresented: $showingRecurringPrompt) {
                Button("Make recurring") {
                    pendingRecurringEvent?.specificDate = nil
                    try? modelContext.save()
                    dismiss()
                }
                Button("Not now", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("You've added \"\(pendingRecurringEvent?.name ?? "this")\" every week for the last 3 weeks. Want it to repeat automatically starting now?")
            }
            .alert("New category", isPresented: $showingAddCategory) {
                TextField("e.g. Volunteering", text: $newCategoryText)
                Button("Add") {
                    let trimmed = newCategoryText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let resolved = EventCategory.resolve(trimmed, existingOptions: categoryOptions)
                    category = resolved
                    applyCategorySuggestion(for: resolved)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        // Swiping a sheet away is easy to trigger by accident (a stray downward drag while
        // scrolling the form) — once there's a name typed in, that's real, unsaved content
        // worth protecting, so the swipe gesture is disabled and "Cancel" (a deliberate tap,
        // not an accidental one) becomes the only way to leave without saving.
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: Helpers

    private var formattedDuration: String { formatMinutes(durationMinutes) }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    // Days from today through the end of the week, in locale-aware chronological order — a
    // due date can't be set in the past. Reuses Scheduler.eligibleDays, the exact same
    // question the placement algorithm itself asks, rather than a second rawValue-based copy —
    // an earlier version of this property used plain rawValue comparison, which is wrong for
    // a US-locale week (Sunday is chronologically first, not last — see the 2026-09-27 Stray
    // Spark log entry) and would have silently offered an already-past Sunday as a valid due
    // date, or hidden a same-week Sunday that's still genuinely upcoming.
    private var availableDueDays: [DayOfWeek] {
        Scheduler.eligibleDays(from: SchedulerService.todayAsDayOfWeek())
    }

    // Can't usefully split into more sessions than there are days between today and the
    // chosen due day, inclusive — computed as a position within availableDueDays (the same
    // locale-aware ordering), not raw rawValue subtraction, for the same reason as above.
    private var maxSplitSessions: Int {
        guard let dueDayIndex = availableDueDays.firstIndex(of: dueDay) else { return 2 }
        return max(2, dueDayIndex + 1)
    }

    // Pre-fills the energy label from the category's learned baseline, if one exists yet —
    // but only before the user has manually picked a label themselves this session. Once
    // energyManuallySet is true, this only updates the hint text, never the actual selection,
    // so a later category change can't silently clobber an explicit choice.
    private func applyCategorySuggestion(for newCategory: String) {
        guard let suggested = PatternService.suggestedLabel(for: newCategory) else {
            categorySuggestionHint = nil
            return
        }
        categorySuggestionHint = "Suggested from your past \(newCategory) entries"
        guard !energyManuallySet else { return }
        selectedLabel = suggested
        energyCost = suggested.cost
    }

    private func saveEvent() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if isFixed {
            // Only a real candidate-window set if there are at least 2 genuinely valid
            // (end after start) options — the Save button is already disabled below this
            // bar, so reaching here with hasCandidateWindows true means it's already met.
            let validWindows = validCandidateWindows
            let useCandidates = hasCandidateWindows && validWindows.count >= 2

            for day in selectedDays.sorted(by: { $0.rawValue < $1.rawValue }) {
                if globalPatternLearning {
                    PatternService.shared.record(energyCost: energyCost, for: category)
                }
                modelContext.insert(Event(
                    name: trimmedName,
                    isFixed: true,
                    fixedDay: day,
                    // The first candidate stands in as the displayed time until the next
                    // "Build my week" actually resolves the best one (SchedulerService.
                    // resolveCandidateWindows) — same "sits as unscheduled/unresolved until
                    // the next explicit build" pattern flexible placement already uses.
                    startTime: useCandidates ? validWindows[0].start : startTime,
                    endTime: useCandidates ? validWindows[0].end : endTime,
                    energyCost: energyCost,
                    category: category,
                    patternLearningEnabled: globalPatternLearning,
                    candidateStartTimes: useCandidates ? validWindows.map(\.start) : [],
                    candidateEndTimes: useCandidates ? validWindows.map(\.end) : []
                ))
            }
        } else {
            let deadline = hasDueDate ? SchedulerService.date(for: dueDay, weekStart: SchedulerService.weekStart()) : nil
            let shouldSplit = hasDueDate && wantsSplit && durationMinutes > 60 && splitSessionCount > 1

            if shouldSplit, let deadline {
                let sessions = TaskSplitService.makeSessions(
                    name: trimmedName,
                    totalDurationMinutes: durationMinutes,
                    sessionCount: splitSessionCount,
                    energyCost: energyCost,
                    category: category,
                    deadline: deadline,
                    isThisWeekOnly: isThisWeekOnly,
                    isPriority: isPriority,
                    patternLearningEnabled: globalPatternLearning,
                    preferredWindow: preferredWindow
                )
                for session in sessions {
                    modelContext.insert(session)
                    if globalPatternLearning {
                        PatternService.shared.record(energyCost: energyCost, for: category)
                    }
                }
                // A split task is several distinct sessions, not one recurring habit — the
                // "add this every week?" prompt below assumes a single event reappearing
                // under the same name, which doesn't fit this shape.
            } else {
                if globalPatternLearning {
                    PatternService.shared.record(energyCost: energyCost, for: category)
                }
                let newEvent = Event(
                    name: trimmedName,
                    isFixed: false,
                    specificDate: isThisWeekOnly ? Date() : nil,
                    preferredWindow: preferredWindow,
                    duration: TimeInterval(durationMinutes * 60),
                    energyCost: energyCost,
                    category: category,
                    patternLearningEnabled: globalPatternLearning,
                    deadline: deadline,
                    isPriority: isPriority
                )
                modelContext.insert(newEvent)
                if isThisWeekOnly, SchedulerService.hasRecurringPattern(name: trimmedName, events: events + [newEvent]) {
                    pendingRecurringEvent = newEvent
                    showingRecurringPrompt = true
                    return   // don't dismiss yet — wait for the alert response
                }
            }
        }
        dismiss()
    }
}

// MARK: - Day Chip

private struct DayChip: View {
    let label: String
    let isSelected: Bool
    var fullLabel: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(NimvaFont.captionSemi)
                .foregroundStyle(isSelected ? .white : NimvaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? NimvaColors.purplePrimary : NimvaColors.surfaceDeep)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(fullLabel ?? label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Selected" : "Tap to select")
    }
}

// MARK: - Time Parsing
// Shared by TimeInputRow and tests. Tries common time string formats in order;
// preserves the date component of `base` so callers don't lose the day.
func parseTimeString(_ input: String, relativeTo base: Date) -> Date? {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let formats = ["h:mm a", "h:mma", "H:mm", "h:mm", "h a", "ha"]
    let cal = Calendar.current
    var baseComps = cal.dateComponents([.year, .month, .day], from: base)
    for format in formats {
        let f = DateFormatter()
        f.dateFormat = format
        if let parsed = f.date(from: trimmed) {
            let t = cal.dateComponents([.hour, .minute], from: parsed)
            baseComps.hour = t.hour
            baseComps.minute = t.minute
            return cal.date(from: baseComps)
        }
    }
    return nil
}

// MARK: - Time Input Row
// Shared by AddEventView and EditEventView. Shows the time as a typeable text field;
// falls back to the previous value if the input can't be parsed.

struct TimeInputRow: View {
    let label: String
    @Binding var date: Date

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short  // "9:30 AM"
        return f
    }()

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(NimvaColors.textPrimary)
            Spacer()
            TextField("9:00 AM", text: $text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(NimvaColors.textSecondary)
                .focused($isFocused)
                .onSubmit { commit() }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onAppear { text = Self.displayFormatter.string(from: date) }
                .onChange(of: date) { _, d in
                    if !isFocused { text = Self.displayFormatter.string(from: d) }
                }
        }
    }

    private func commit() {
        if let result = parseTimeString(text, relativeTo: date) {
            date = result
        }
        text = Self.displayFormatter.string(from: date)
    }
}
