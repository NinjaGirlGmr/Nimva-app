import SwiftUI
import SwiftData

struct AddEventView: View {
    // @Environment pulls values SwiftUI manages for us automatically.
    // modelContext is the SwiftData "save file" — we call modelContext.insert()
    // to save a new event, and modelContext.delete() to remove one.
    @Environment(\.modelContext) private var modelContext

    // dismiss() is a function SwiftUI gives us to close this sheet.
    @Environment(\.dismiss) private var dismiss

    // @State holds temporary form data while the user is filling things out.
    // SwiftUI watches these — any change causes the view to redraw automatically.
    @State private var name: String = ""
    @State private var isFixed: Bool = true
    @State private var selectedDay: DayOfWeek = .monday
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var preferredWindow: TimePreference = .any
    @State private var durationMinutes: Int = 60
    @State private var selectedLabel: EnergyLabel = .manageable
    @State private var energyCost: Double = EnergyLabel.manageable.cost
    @State private var patternLearningEnabled: Bool = true
    @State private var category: String = "General"

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Event type
                // Picker with .segmented style renders as the Fixed | Flexible toggle
                // from the design. $isFixed is a "binding" — a two-way connection
                // between the picker and the @State variable above.
                Section {
                    Picker("Event type", selection: $isFixed) {
                        Text("Fixed").tag(true)
                        Text("Flexible").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Name
                Section("Event name") {
                    TextField("What's the event?", text: $name)
                }

                // MARK: Timing — changes based on event type
                // SwiftUI only builds the views inside an `if` when the condition
                // is true, so the Fixed fields disappear entirely when Flexible
                // is selected, and vice versa.
                if isFixed {
                    Section("Timing") {
                        Picker("Day", selection: $selectedDay) {
                            ForEach(DayOfWeek.allCases, id: \.self) { day in
                                Text(day.displayName).tag(day)
                            }
                        }
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                } else {
                    Section("Timing") {
                        Picker("Preferred window", selection: $preferredWindow) {
                            ForEach(TimePreference.allCases, id: \.self) { window in
                                Text(window.displayName).tag(window)
                            }
                        }
                        // Stepper lets the user increment/decrement duration in 15-min steps
                        Stepper(
                            value: $durationMinutes,
                            in: 15...480,
                            step: 15
                        ) {
                            Text("Duration: \(formattedDuration)")
                        }
                    }

                    // Nimva note shown only for flexible events, per the design
                    Section {
                        Label(
                            "Nimva will find the best slot based on your energy load",
                            systemImage: "sparkles"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                // MARK: Energy
                Section("Energy") {
                    // LazyVGrid arranges children in a grid.
                    // GridItem(.flexible()) means each column stretches to fill available width.
                    // Repeating it twice gives us a 2-column layout.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            Button {
                                selectedLabel = label
                                energyCost = label.cost
                            } label: {
                                Text(label.displayName)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedLabel == label ? .purple : .secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Fine-tune slider — lets the user nudge the cost within the
                    // selected label's general range
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fine-tune")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $energyCost, in: 0.0...1.0, step: 0.01)
                            .tint(.purple)
                    }
                }

                // MARK: Pattern learning toggle
                Section {
                    Toggle("Learn my patterns", isOn: $patternLearningEnabled)
                } footer: {
                    Text("Nimva uses your check-in ratings to improve suggestions over time.")
                        .font(.caption)
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to week") { saveEvent() }
                        // .disabled greys out the button and blocks taps when name is empty
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: Helpers

    private var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    // Creates the Event model and hands it to SwiftData to persist
    private func saveEvent() {
        let event = Event(
            name: name.trimmingCharacters(in: .whitespaces),
            isFixed: isFixed,
            fixedDay: isFixed ? selectedDay : nil,
            startTime: isFixed ? startTime : nil,
            endTime: isFixed ? endTime : nil,
            preferredWindow: isFixed ? nil : preferredWindow,
            duration: isFixed ? nil : TimeInterval(durationMinutes * 60),
            energyCost: energyCost,
            category: category,
            patternLearningEnabled: patternLearningEnabled
        )
        // insert() tells SwiftData to save this event to persistent storage.
        // It's automatically synced to CloudKit once that's configured.
        modelContext.insert(event)
        dismiss()
    }
}
