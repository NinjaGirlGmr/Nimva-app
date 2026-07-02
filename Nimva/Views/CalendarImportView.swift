import SwiftUI

struct CalendarImportView: View {
    let candidates: [CalendarImportService.ImportCandidate]
    let onImport: ([CalendarImportService.ImportCandidate]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String>

    init(
        candidates: [CalendarImportService.ImportCandidate],
        onImport: @escaping ([CalendarImportService.ImportCandidate]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.candidates = candidates
        self.onImport = onImport
        self.onCancel = onCancel
        _selected = State(initialValue: Set(candidates.map(\.id)))
    }

    private var selectedCandidates: [CalendarImportService.ImportCandidate] {
        candidates.filter { selected.contains($0.id) }
    }

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if candidates.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(candidates) { candidate in
                                candidateRow(candidate)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }

                    actionBar
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.system(size: 14))
                    .foregroundStyle(NimvaColors.textMuted)
                    .padding(.trailing, 20)
            }
            .padding(.top, 16)

            Text("📅")
                .font(.system(size: 42))

            Text(candidates.isEmpty ? "All caught up" : "Found \(candidates.count) new \(candidates.count == 1 ? "event" : "events")")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(NimvaColors.textPrimary)

            Text(candidates.isEmpty
                ? "Your Apple Calendar events are already in Nimva."
                : "Select which events to add to this week.")
                .font(.system(size: 13))
                .foregroundStyle(NimvaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Button("Done", action: onCancel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(NimvaColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Candidate row

    private func candidateRow(_ candidate: CalendarImportService.ImportCandidate) -> some View {
        let isOn = selected.contains(candidate.id)
        return Button {
            if isOn { selected.remove(candidate.id) }
            else    { selected.insert(candidate.id) }
        } label: {
            HStack(spacing: 12) {
                // Checkbox circle
                ZStack {
                    Circle()
                        .fill(isOn ? NimvaColors.purplePrimary : Color.clear)
                        .frame(width: 22, height: 22)
                    Circle()
                        .stroke(isOn ? NimvaColors.purplePrimary : NimvaColors.border, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NimvaColors.textPrimary)
                        .lineLimit(1)
                    Text(timeLabel(for: candidate))
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textMuted)
                }

                Spacer()

                // Day chip
                Text(candidate.day.shortName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NimvaColors.purplePrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NimvaColors.purplePrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func timeLabel(for candidate: CalendarImportService.ImportCandidate) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return "\(fmt.string(from: candidate.startTime)) – \(fmt.string(from: candidate.endTime))"
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(NimvaColors.border)
                .frame(height: 1)

            let count = selectedCandidates.count
            Button {
                onImport(selectedCandidates)
            } label: {
                Text(count == 0
                    ? "Select events to import"
                    : "Import \(count) \(count == 1 ? "event" : "events")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(count == 0 ? NimvaColors.textMuted.opacity(0.4) : NimvaColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(count == 0)
            .padding(.horizontal, 20)

            Button("Cancel", action: onCancel)
                .font(.system(size: 14))
                .foregroundStyle(NimvaColors.textMuted)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(NimvaColors.background)
    }
}
