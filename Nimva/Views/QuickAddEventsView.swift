import SwiftUI
import SwiftData

// Batch-add flow: rapid-fire several flexible events (a pile of homework, say) without
// reopening the full AddEventView form once per item. Picked one energy label + one category
// for the running batch, type a name, hit Add (or return), repeat — the keyboard never has
// to close between items. See QuickAddService for the underlying, independently-tested logic.
struct QuickAddEventsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.createdAt) private var events: [Event]

    @State private var draftText: String = ""
    @State private var items: [QuickAddService.Item] = []
    @State private var category: String = "General"
    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var energyCost: Double = EnergyLabel.manageable.cost
    // Same reasoning as AddEventView: a category-based suggestion should only ever pre-fill
    // before the user has touched the picker themselves, never override an explicit tap.
    @State private var energyManuallySet = false
    @State private var categorySuggestionHint: String? = nil
    @State private var isThisWeekOnly: Bool = true
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true
    @State private var showingAddCategory = false
    @State private var newCategoryText = ""
    @FocusState private var draftFieldFocused: Bool

    private var categoryOptions: [String] {
        let custom = Set(events.map(\.category)).union([category]).subtracting(EventCategory.presets)
        return EventCategory.presets + custom.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "Add a few things at once — pick a category and energy level, then keep typing names without leaving this screen.",
                        systemImage: "bolt.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(NimvaColors.textMuted)
                }
                .listRowBackground(NimvaColors.cardDark)

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .foregroundStyle(NimvaColors.textPrimary)
                    .onChange(of: category) { _, newValue in applyCategorySuggestion(for: newValue) }

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

                Section("Energy for this batch") {
                    if let hint = categorySuggestionHint {
                        Label(hint, systemImage: "sparkles")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    Text("Applies to items you add from here on — change it partway through if something's different from the rest.")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                    VStack(spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            Button {
                                selectedLabel = label
                                energyCost = label.cost
                                energyManuallySet = true
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
                        }
                    }
                    .padding(.vertical, 4)

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
                }
                .listRowBackground(NimvaColors.cardDark)

                Section("Add items") {
                    HStack {
                        TextField("e.g. Chem worksheet", text: $draftText)
                            .foregroundStyle(NimvaColors.textPrimary)
                            .focused($draftFieldFocused)
                            .submitLabel(.done)
                            .onSubmit(addDraft)
                        Button {
                            addDraft()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(.title2))
                                .foregroundStyle(
                                    draftText.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? NimvaColors.textMuted
                                        : NimvaColors.teal
                                )
                        }
                        .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Add item")
                    }
                }
                .listRowBackground(NimvaColors.cardDark)

                if !items.isEmpty {
                    Section("Queued (\(items.count))") {
                        ForEach(items) { item in
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(NimvaColors.textPrimary)
                                Spacer()
                                Text(EnergyLabel.closest(to: item.energyCost).displayName)
                                    .font(NimvaFont.micro)
                                    .foregroundStyle(NimvaColors.textMuted)
                            }
                        }
                        .onDelete { offsets in items.remove(atOffsets: offsets) }
                    }
                    .listRowBackground(NimvaColors.cardDark)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NimvaColors.background)
            .navigationTitle("Quick add")
            .navigationBarTitleDisplayMode(.inline)
            .tint(NimvaColors.purplePrimary)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { draftFieldFocused = false }
                        .foregroundStyle(NimvaColors.purplePrimary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NimvaColors.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(pendingCount)") { saveAll() }
                        .disabled(pendingCount == 0)
                }
            }
            .alert("New category", isPresented: $showingAddCategory) {
                TextField("e.g. Volunteering", text: $newCategoryText)
                Button("Add") {
                    let trimmed = newCategoryText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    category = EventCategory.resolve(trimmed, existingOptions: categoryOptions)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                applyCategorySuggestion(for: category)
                draftFieldFocused = true
            }
        }
        // Same reasoning as AddEventView/LogEntryView/AddIntentionView: protect queued items
        // (and anything still typed) from an accidental swipe-dismiss.
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // Counts the draft field's in-progress text as pending too, so the toolbar button's
    // count — and whether it's enabled — reflects what Save would actually create, not just
    // what's already been explicitly added to the queue.
    private var pendingCount: Int {
        items.count + (draftText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
    }

    private var hasUnsavedChanges: Bool {
        !items.isEmpty || !draftText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addDraft() {
        guard let item = QuickAddService.makeItem(rawName: draftText, energyCost: energyCost) else { return }
        items.append(item)
        draftText = ""
        // Keep focus so the next name can be typed immediately — the whole point of a quick
        // add flow is never having to re-tap the text field between items.
        draftFieldFocused = true
    }

    // Mirrors AddEventView's category-suggestion behavior: pre-fill from the category's
    // learned baseline, but only before the user has manually picked a label themselves.
    private func applyCategorySuggestion(for newCategory: String) {
        guard !energyManuallySet,
              let baseline = PatternService.shared.baseline(for: newCategory) else {
            categorySuggestionHint = nil
            return
        }
        selectedLabel = EnergyLabel.closest(to: baseline)
        energyCost = baseline
        categorySuggestionHint = "Suggested from your past \(newCategory) entries"
    }

    private func saveAll() {
        // Anything still sitting in the text field when "Add N" is tapped should be included,
        // not silently dropped.
        addDraft()
        guard !items.isEmpty else { return }

        let newEvents = QuickAddService.makeEvents(
            from: items,
            category: category,
            isThisWeekOnly: isThisWeekOnly,
            patternLearningEnabled: globalPatternLearning
        )
        for event in newEvents {
            modelContext.insert(event)
        }
        if globalPatternLearning {
            for item in items {
                PatternService.shared.record(energyCost: item.energyCost, for: category)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
