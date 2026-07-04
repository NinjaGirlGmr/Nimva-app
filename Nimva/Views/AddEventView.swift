import SwiftUI
import SwiftData

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var isFixed: Bool = true
    @State private var selectedDays: Set<DayOfWeek> = [.monday]
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

                // MARK: Timing
                if isFixed {
                    Section("Timing") {
                        // Multi-day chips — tap to toggle; great for recurring events like MWF classes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Day")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                ForEach(DayOfWeek.allCases, id: \.self) { day in
                                    DayChip(
                                        label: String(day.shortName.prefix(2)),
                                        isSelected: selectedDays.contains(day)
                                    ) {
                                        if selectedDays.contains(day) {
                                            // Keep at least one day selected
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
                    }
                } else {
                    Section("Timing") {
                        Picker("Preferred window", selection: $preferredWindow) {
                            ForEach(TimePreference.allCases, id: \.self) { window in
                                Text(window.displayName).tag(window)
                            }
                        }
                        Stepper(
                            value: $durationMinutes,
                            in: 15...480,
                            step: 15
                        ) {
                            Text("Duration: \(formattedDuration)")
                        }
                    }

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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fine-tune")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $energyCost, in: 0.0...1.0, step: 0.01)
                            .tint(.purple)
                    }
                }

                // MARK: Pattern learning
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

    // Creates one Event per selected day for fixed events (supports MWF-style recurring).
    private func saveEvent() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if isFixed {
            for day in selectedDays.sorted(by: { $0.rawValue < $1.rawValue }) {
                modelContext.insert(Event(
                    name: trimmedName,
                    isFixed: true,
                    fixedDay: day,
                    startTime: startTime,
                    endTime: endTime,
                    energyCost: energyCost,
                    category: category,
                    patternLearningEnabled: patternLearningEnabled
                ))
            }
        } else {
            modelContext.insert(Event(
                name: trimmedName,
                isFixed: false,
                preferredWindow: preferredWindow,
                duration: TimeInterval(durationMinutes * 60),
                energyCost: energyCost,
                category: category,
                patternLearningEnabled: patternLearningEnabled
            ))
        }
        dismiss()
    }
}

// MARK: - Day Chip

private struct DayChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
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
            Spacer()
            TextField("9:00 AM", text: $text)
                .multilineTextAlignment(.trailing)
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
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let formats = ["h:mm a", "h:mma", "H:mm", "h:mm", "h a", "ha"]
        let cal = Calendar.current
        var base = cal.dateComponents([.year, .month, .day], from: date)

        for format in formats {
            let f = DateFormatter()
            f.dateFormat = format
            if let parsed = f.date(from: trimmed) {
                let t = cal.dateComponents([.hour, .minute], from: parsed)
                base.hour = t.hour
                base.minute = t.minute
                if let result = cal.date(from: base) {
                    date = result
                    text = Self.displayFormatter.string(from: result)
                    return
                }
            }
        }
        // Reset to current value if parse failed
        text = Self.displayFormatter.string(from: date)
    }
}
