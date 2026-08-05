import SwiftUI
import SwiftData

// Quick, retroactive "log something that happened" entry — deliberately minimal compared to
// AddEventView, since none of the scheduling-specific fields (fixed/flexible choice, time
// window, duration, priority, repeats) mean anything for something that's already over.
// Creates a wasLogged event pinned to today; SchedulerService treats it like a fixed event
// for load purposes (see toLoggedFixedEvent) and it's never a placement candidate.
struct LogEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.createdAt) private var events: [Event]

    @State private var name: String = ""
    @State private var category: String = "General"
    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var energyCost: Double = EnergyLabel.manageable.cost
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true
    @State private var showingAddCategory = false
    @State private var newCategoryText = ""
    @FocusState private var nameFieldFocused: Bool

    // Same derivation as AddEventView/EditEventView — presets plus whatever custom
    // categories are already in use.
    private var categoryOptions: [String] {
        let custom = Set(events.map(\.category)).union([category]).subtracting(EventCategory.presets)
        return EventCategory.presets + custom.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "For something that already happened — not a scheduling entry.",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.footnote)
                    .foregroundStyle(NimvaColors.textMuted)
                }
                .listRowBackground(NimvaColors.cardDark)

                Section("What happened?") {
                    TextField("e.g. Officer duty emails", text: $name)
                        .foregroundStyle(NimvaColors.textPrimary)
                        .focused($nameFieldFocused)
                }
                .listRowBackground(NimvaColors.cardDark)

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .foregroundStyle(NimvaColors.textPrimary)

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

                Section("How draining was it?") {
                    VStack(spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            Button {
                                selectedLabel = label
                                energyCost = label.cost
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
                }
                .listRowBackground(NimvaColors.cardDark)
            }
            .scrollContentBackground(.hidden)
            .background(NimvaColors.background)
            .navigationTitle("Log Something")
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
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
        }
        // See AddEventView's matching modifier — same reasoning: protect a typed-in name
        // from an accidental swipe-dismiss, while a deliberate "Cancel" tap still works.
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    private var hasUnsavedChanges: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        if globalPatternLearning {
            PatternService.shared.record(energyCost: energyCost, for: category)
        }
        let newEvent = Event(
            name: trimmedName,
            isFixed: false,
            specificDate: Date(),
            preferredWindow: .any,
            duration: nil,
            energyCost: energyCost,
            category: category,
            patternLearningEnabled: globalPatternLearning,
            wasLogged: true
        )
        modelContext.insert(newEvent)
        try? modelContext.save()
        dismiss()
    }
}
