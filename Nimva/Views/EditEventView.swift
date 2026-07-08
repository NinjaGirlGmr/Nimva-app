import SwiftUI
import SwiftData

struct EditEventView: View {
    // @Bindable is the SwiftData equivalent of @State for an existing model.
    // It creates two-way bindings ($event.name, $event.energyCost, etc.) that
    // write directly back to SwiftData whenever the user makes a change.
    // No "save" button needed — changes persist automatically.
    @Bindable var event: Event

    @Environment(\.dismiss) private var dismiss

    // Local state just for the label chip selection — the chips update energyCost
    // on the model directly, but we need a separate variable to track which chip
    // is visually highlighted.
    @State private var selectedLabel: EnergyLabel = .manageable

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Event type
                Section {
                    Picker("Event type", selection: $event.isFixed) {
                        Text("Fixed").tag(true)
                        Text("Flexible").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Name
                Section("Event name") {
                    TextField("What's the event?", text: $event.name)
                }

                // MARK: Timing
                if event.isFixed {
                    Section("Timing") {
                        // When event.fixedDay is nil (shouldn't happen for a fixed event
                        // but we need to handle it safely), default to .monday
                        Picker("Day", selection: Binding(
                            get: { event.fixedDay ?? .monday },
                            set: { event.fixedDay = $0 }
                        )) {
                            ForEach(DayOfWeek.allCases, id: \.self) { day in
                                Text(day.displayName).tag(day)
                            }
                        }
                        TimeInputRow(label: "Start time", date: Binding(
                            get: { event.startTime ?? Date() },
                            set: { event.startTime = $0 }
                        ))
                        TimeInputRow(label: "End time", date: Binding(
                            get: { event.endTime ?? Date() },
                            set: { event.endTime = $0 }
                        ))
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
                        Stepper(
                            value: Binding(
                                get: { Int((event.duration ?? 3600) / 60) },
                                set: { event.duration = TimeInterval($0 * 60) }
                            ),
                            in: 15...480,
                            step: 15
                        ) {
                            Text("Duration: \(formattedDuration)")
                        }
                    }
                }

                // MARK: Energy
                Section("Energy") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            Button {
                                selectedLabel = label
                                event.energyCost = label.cost
                            } label: {
                                Text(label.displayName)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedLabel == label ? NimvaColors.purplePrimary : NimvaColors.textMuted)
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fine-tune")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $event.energyCost, in: 0.0...1.0, step: 0.01)
                            .tint(NimvaColors.purplePrimary)
                    }
                }

                // MARK: Pattern learning
                Section {
                    Toggle("Learn my patterns", isOn: $event.patternLearningEnabled)
                } footer: {
                    Text("Nimva uses your check-in ratings to improve suggestions over time.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NimvaColors.background)
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .tint(NimvaColors.purplePrimary)
            .onAppear {
                // Set the chip highlight to whichever label is closest to the stored cost
                selectedLabel = EnergyLabel.allCases.min(by: {
                    abs($0.cost - event.energyCost) < abs($1.cost - event.energyCost)
                }) ?? .manageable
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
