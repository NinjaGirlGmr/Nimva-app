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
    @State private var isPriority: Bool = false
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true
    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @State private var category: String = "General"
    @FocusState private var nameFieldFocused: Bool

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

                    Section("Priority") {
                        Toggle(isOn: $isPriority) {
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

                // MARK: Energy
                Section("Energy") {
                    VStack(spacing: 8) {
                        ForEach(EnergyLabel.allCases, id: \.self) { label in
                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    selectedLabel = label
                                    energyCost = label.cost
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
                                  (isFixed && endTime <= startTime))
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
                    patternLearningEnabled: globalPatternLearning
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
                patternLearningEnabled: globalPatternLearning,
                isPriority: isPriority
            ))
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
                .font(.system(size: 12, weight: .semibold))
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
