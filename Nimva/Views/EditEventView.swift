import SwiftUI
import SwiftData

struct EditEventView: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.createdAt) private var events: [Event]

    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var showingDeleteConfirm = false
    @State private var pendingTypeSwitch: Bool? = nil
    @State private var categorySuggestionHint: String? = nil
    // Captured on appear so Done only records a data point if the label actually changed
    // during this edit — opening and closing without touching Energy shouldn't count.
    @State private var initialEnergyCost: Double = 0.5
    @State private var showingAddCategory = false
    @State private var newCategoryText = ""
    @State private var showingAdvanced = false
    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @FocusState private var nameFieldFocused: Bool

    // Same derivation as AddEventView — built-in presets, then whatever custom categories
    // are already in use, always including this event's own current category.
    private var categoryOptions: [String] {
        let custom = Set(events.map(\.category)).union([event.category]).subtracting(EventCategory.presets)
        return EventCategory.presets + custom.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Event type
                Section {
                    Picker("Event type", selection: Binding(
                        get: { event.isFixed },
                        set: { newValue in
                            if newValue != event.isFixed { pendingTypeSwitch = newValue }
                        }
                    )) {
                        Text("Fixed").tag(true)
                        Text("Flexible").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Name
                Section("Event name") {
                    TextField("What's the event?", text: $event.name)
                        .foregroundStyle(NimvaColors.textPrimary)
                        .focused($nameFieldFocused)
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Category
                Section("Category") {
                    Picker("Category", selection: $event.category) {
                        ForEach(categoryOptions, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .foregroundStyle(NimvaColors.textPrimary)
                    .onChange(of: event.category) { _, newCategory in
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
                if event.isFixed {
                    Section("Timing") {
                        Picker("Day", selection: Binding(
                            get: { event.fixedDay ?? .monday },
                            set: { event.fixedDay = $0 }
                        )) {
                            ForEach(DayOfWeek.orderedForLocale, id: \.self) { day in
                                Text(day.displayName).tag(day)
                            }
                        }
                        .foregroundStyle(NimvaColors.textPrimary)
                        TimeInputRow(label: "Start time", date: Binding(
                            get: { event.startTime ?? Date() },
                            set: { event.startTime = $0 }
                        ))
                        TimeInputRow(label: "End time", date: Binding(
                            get: { event.endTime ?? Date() },
                            set: { event.endTime = $0 }
                        ))
                        if hasTimeError {
                            Text("End time must be after start time")
                                .font(.system(.caption))
                                .foregroundStyle(NimvaColors.coral)
                        }
                    }
                    .listRowBackground(NimvaColors.cardDark)

                    // MARK: Candidate windows (#79) — only present for an event created with
                    // a few possible times. Overriding here is a light correction, not a
                    // separate editor: tapping a different option just picks it directly,
                    // the actual list of options isn't editable from this screen.
                    if !event.candidateStartTimes.isEmpty {
                        Section {
                            Text(event.candidateWindowManuallySet
                                ? "You picked this time — it won't change on your next build."
                                : "Nimva picked this time automatically — it may change on your next build.")
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)

                            ForEach(event.candidateStartTimes.indices, id: \.self) { index in
                                let start = event.candidateStartTimes[index]
                                let end = event.candidateEndTimes.indices.contains(index) ? event.candidateEndTimes[index] : start
                                let isActive = event.startTime == start && event.endTime == end
                                Button {
                                    event.startTime = start
                                    event.endTime = end
                                    event.candidateWindowManuallySet = true
                                } label: {
                                    HStack {
                                        Text(formattedWindowRange(start, end))
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(isActive ? .white : NimvaColors.textSecondary)
                                        Spacer()
                                        if isActive {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(isActive ? NimvaColors.purplePrimary : NimvaColors.surfaceDeep)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.scalePress)
                                .frame(minHeight: 44)
                                .accessibilityAddTraits(isActive ? .isSelected : [])
                            }

                            if event.candidateWindowManuallySet {
                                Button {
                                    event.candidateWindowManuallySet = false
                                } label: {
                                    Label("Let Nimva choose again", systemImage: "arrow.counterclockwise")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.teal)
                                }
                                .buttonStyle(.scalePress)
                                .frame(minHeight: 44)
                            }
                        } header: {
                            Text("Possible times")
                        }
                        .listRowBackground(NimvaColors.cardDark)
                    }
                } else {
                    Section("Timing") {
                        Picker("Preferred window", selection: Binding(
                            get: { event.preferredWindow ?? .any },
                            set: { event.preferredWindow = $0 }
                        )) {
                            ForEach(TimePreference.allCases, id: \.self) { window in
                                Text(window.displayName).tag(window)
                            }
                        }
                        .foregroundStyle(NimvaColors.textPrimary)
                        Stepper(
                            value: Binding(
                                get: { Int((event.duration ?? 3600) / 60) },
                                set: { event.duration = TimeInterval($0 * 60) }
                            ),
                            in: 15...480,
                            step: 15
                        ) {
                            Text("Duration: \(formattedDuration)")
                                .foregroundStyle(NimvaColors.textPrimary)
                        }
                    }
                    .listRowBackground(NimvaColors.cardDark)

                    Section {
                        DisclosureGroup(isExpanded: $showingAdvanced) {
                            Toggle(isOn: $event.isPriority) {
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
                                get: { event.specificDate == nil },
                                set: { everyWeek in event.specificDate = everyWeek ? nil : (event.specificDate ?? Date()) }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.specificDate == nil ? "Every week" : "This week only")
                                        .font(NimvaFont.callout)
                                        .foregroundStyle(NimvaColors.textPrimary)
                                    Text(event.specificDate == nil
                                        ? "Included in every week you build"
                                        : "Won't be included in future weeks")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                            }
                            .tint(NimvaColors.teal)

                            // Due date (#95) — mirrors AddEventView, gated the same way:
                            // a deadline is a one-time calendar date, so it doesn't compose
                            // with "every week" (see SchedulerService.deadlineDay's doc
                            // comment). Splitting into multiple sessions isn't offered here —
                            // TaskSplitService is a creation-time decision (see its own doc
                            // comment); an already-placed single event doesn't turn into N
                            // sessions on edit.
                            if event.specificDate != nil {
                                Divider().padding(.vertical, 2)

                                Toggle(isOn: Binding(
                                    get: { event.deadline != nil },
                                    set: { hasDeadline in
                                        event.deadline = hasDeadline
                                            ? SchedulerService.date(for: currentDueDay, weekStart: eventWeekStart)
                                            : nil
                                    }
                                )) {
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

                                if event.deadline != nil {
                                    Picker("Due by", selection: Binding(
                                        get: { currentDueDay },
                                        set: { newDay in
                                            event.deadline = SchedulerService.date(for: newDay, weekStart: eventWeekStart)
                                        }
                                    )) {
                                        ForEach(availableDueDays, id: \.self) { day in
                                            Text(day.displayName).tag(day)
                                        }
                                    }
                                    .foregroundStyle(NimvaColors.textPrimary)
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

                // MARK: Delete
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete Event")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Energy
                Section("Energy") {
                    if let hint = categorySuggestionHint {
                        Label(hint, systemImage: "sparkles")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    EnergyLabelPicker(
                        selectedLabel: $selectedLabel,
                        energyCost: $event.energyCost,
                        anchorLabel: energyAnchorLabel
                    )
                }
                .listRowBackground(NimvaColors.cardDark)

            }
            // Value-keyed, not a blanket Form-wide animation — see AddEventView's matching
            // modifier for why (typing in the name field shouldn't retrigger a spring).
            .nimvaAnimation(NimvaAnimation.transition, value: event.isFixed)
            .nimvaAnimation(NimvaAnimation.transition, value: event.deadline != nil)
            .nimvaAnimation(NimvaAnimation.transition, value: categorySuggestionHint)
            .scrollContentBackground(.hidden)
            .background(NimvaColors.background)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .tint(NimvaColors.purplePrimary)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { nameFieldFocused = false }
                        .foregroundStyle(NimvaColors.purplePrimary)
                }
            }
            .confirmationDialog(
                "Delete \"\(event.name)\"?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Event", role: .destructive) {
                    modelContext.delete(event)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
            .alert("New category", isPresented: $showingAddCategory) {
                TextField("e.g. Volunteering", text: $newCategoryText)
                Button("Add") {
                    let trimmed = newCategoryText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let resolved = EventCategory.resolve(trimmed, existingOptions: categoryOptions)
                    event.category = resolved
                    applyCategorySuggestion(for: resolved)
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Switch event type?",
                isPresented: Binding(
                    get: { pendingTypeSwitch != nil },
                    set: { if !$0 { pendingTypeSwitch = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Switch type") {
                    guard let pending = pendingTypeSwitch else { return }
                    event.isFixed = pending
                    if pending {
                        event.preferredWindow = nil
                        event.duration = nil
                        event.isPriority = false
                        // Switching to fixed resets to the normal recurring-fixed-event
                        // convention (manually-added fixed events never carry specificDate).
                        event.specificDate = nil
                        // A due date is a flexible-event-only concept (fixed events already
                        // have a locked time, so "due by" doesn't mean anything for them).
                        event.deadline = nil
                    } else {
                        event.fixedDay = nil
                        event.startTime = nil
                        event.endTime = nil
                        // Switching to flexible defaults to "this week only," matching a
                        // freshly-added flexible event's own default.
                        event.specificDate = Date()
                    }
                    pendingTypeSwitch = nil
                }
                Button("Cancel", role: .cancel) { pendingTypeSwitch = nil }
            } message: {
                Text("Switching will clear your timing settings.")
            }
            .onAppear {
                selectedLabel = EnergyLabel.closest(to: event.energyCost)
                initialEnergyCost = event.energyCost
                // Start expanded if either setting is already non-default, so an existing
                // priority/recurring event's state isn't hidden behind a collapsed section.
                showingAdvanced = event.isPriority || event.specificDate == nil || event.deadline != nil
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if event.patternLearningEnabled, event.energyCost != initialEnergyCost {
                            PatternService.shared.record(energyCost: event.energyCost, for: event.category)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(hasTimeError)
                }
            }
        }
    }

    // Informational only — unlike AddEventView, editing always starts from an energy cost
    // the user already deliberately set (possibly a while ago). Recategorizing an existing
    // event must never silently overwrite that live model value with no cancel path, so this
    // only ever updates the hint text; the user has to tap a label themselves to change it.
    private func applyCategorySuggestion(for newCategory: String) {
        guard let suggested = PatternService.suggestedLabel(for: newCategory) else {
            categorySuggestionHint = nil
            return
        }
        categorySuggestionHint = "Your past \(newCategory) entries are usually \"\(suggested.displayName)\""
    }


    // Which day event.deadline currently falls on, for display — falls back to today only
    // in the (shouldn't-happen) case of a corrupt/unreadable date, never silently crashes.
    // The week event.deadline should be resolved/written against — the event's OWN week
    // (from specificDate), not blindly "today's real current week." EditEventView is only
    // ever reached for a current-week event today, so this is latent, not live — but writing
    // it against the wrong week would silently drop the due-date constraint the moment this
    // view can be opened for a future week's event (the rolling multi-week calendar already
    // on the roadmap), since SchedulerService.deadlineDay's weekOfYear check would then never
    // match. Falls back to the real current week only for a recurring "every week" event,
    // which has no specificDate to anchor to — a case the due-date UI is gated off for anyway.
    private var eventWeekStart: Date {
        guard let specific = event.specificDate else { return SchedulerService.weekStart() }
        return SchedulerService.weekStart(for: specific)
    }

    private var currentDueDay: DayOfWeek {
        guard let deadline = event.deadline else { return SchedulerService.todayAsDayOfWeek() }
        return CalendarImportService.nimvaDay(from: deadline) ?? SchedulerService.todayAsDayOfWeek()
    }

    // Locale-aware chronological order (Scheduler.eligibleDays — see its doc comment for why
    // rawValue comparison alone is wrong here), plus the event's own already-set due day if
    // it's somehow outside that range (e.g. edited a few days after creation) — so opening
    // this picker never makes an existing selection just disappear from the list.
    private var availableDueDays: [DayOfWeek] {
        var days = Scheduler.eligibleDays(from: SchedulerService.todayAsDayOfWeek())
        if event.deadline != nil, !days.contains(currentDueDay) {
            days.append(currentDueDay)
            days.sort { $0.rawValue < $1.rawValue }
        }
        return days
    }

    private var hasTimeError: Bool {
        guard event.isFixed, let start = event.startTime, let end = event.endTime else { return false }
        return end <= start
    }

    private var formattedDuration: String {
        let total = Int((event.duration ?? 3600) / 60)
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

}
