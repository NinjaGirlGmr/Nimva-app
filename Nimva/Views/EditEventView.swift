import SwiftUI
import SwiftData

struct EditEventView: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var showingDeleteConfirm = false
    @State private var pendingTypeSwitch: Bool? = nil
    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @FocusState private var nameFieldFocused: Bool

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

                    Section("Priority") {
                        Toggle(isOn: $event.isPriority) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Must do this week")
                                    .font(.system(size: 14))
                                    .foregroundStyle(NimvaColors.textPrimary)
                                Text("Scheduled before nice-to-do events")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NimvaColors.textMuted)
                            }
                        }
                        .tint(NimvaColors.amber)
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
                    VStack(spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    selectedLabel = label
                                    event.energyCost = label.cost
                                } label: {
                                    Text(label.displayName)
                                        .font(.system(size: 14, weight: .medium))
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
                                        .font(.system(size: 11))
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
                    } else {
                        event.fixedDay = nil
                        event.startTime = nil
                        event.endTime = nil
                    }
                    pendingTypeSwitch = nil
                }
                Button("Cancel", role: .cancel) { pendingTypeSwitch = nil }
            } message: {
                Text("Switching will clear your timing settings.")
            }
            .onAppear {
                selectedLabel = EnergyLabel.allCases.min(by: {
                    abs($0.cost - event.energyCost) < abs($1.cost - event.energyCost)
                }) ?? .manageable
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
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
