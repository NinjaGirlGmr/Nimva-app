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
                                    Text("Scheduled before nice-to-do events")
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
                                        ? "A candidate for every week you build"
                                        : "Won't carry over to future weeks")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                }
                            }
                            .tint(NimvaColors.teal)
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
                    VStack(spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    selectedLabel = label
                                    event.energyCost = label.cost
                                } label: {
                                    Text(label.displayName)
                                        .font(NimvaFont.calloutMed)
                                        .foregroundStyle(selectedLabel == label ? .white : NimvaColors.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedLabel == label ? NimvaColors.purplePrimary : NimvaColors.surfaceDeep)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedLabel == label ? NimvaColors.purplePrimary : NimvaColors.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .frame(minHeight: 44)
                                .accessibilityAddTraits(selectedLabel == label ? .isSelected : [])

                                if label == .prettyDraining && !energyAnchorLabel.isEmpty {
                                    Text("Like: \(energyAnchorLabel)")
                                        .font(NimvaFont.micro)
                                        .foregroundStyle(NimvaColors.textMuted)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(NimvaColors.cardDark)

            }
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
                showingAdvanced = event.isPriority || event.specificDate == nil
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
        guard newCategory != "General",
              let baseline = PatternService.shared.baseline(for: newCategory) else {
            categorySuggestionHint = nil
            return
        }
        let label = EnergyLabel.closest(to: baseline)
        categorySuggestionHint = "Your past \(newCategory) entries tend to run \"\(label.displayName)\""
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
