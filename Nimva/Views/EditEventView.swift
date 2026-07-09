import SwiftUI
import SwiftData

struct EditEventView: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss

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
                .listRowBackground(NimvaColors.cardDark)

                // MARK: Name
                Section("Event name") {
                    TextField("What's the event?", text: $event.name)
                        .foregroundStyle(NimvaColors.textPrimary)
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
            .onAppear {
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
