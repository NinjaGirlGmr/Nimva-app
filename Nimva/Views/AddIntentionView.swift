import SwiftUI
import SwiftData

struct AddIntentionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Something I want to do this week...", text: $text, axis: .vertical)
                    .font(NimvaFont.body)
                    .foregroundStyle(NimvaColors.textPrimary)
                    .focused($focused)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(NimvaColors.cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Intentions aren't tasks — just a gentle direction for your open time.")
                    .font(NimvaFont.micro)
                    .foregroundStyle(NimvaColors.textMuted)

                Spacer()
            }
            .padding(20)
            .background(NimvaColors.background)
            .navigationTitle("Add intention")
            .navigationBarTitleDisplayMode(.inline)
            .tint(NimvaColors.purplePrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NimvaColors.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Intention(text: trimmed, weekOf: SchedulerService.weekStart()))
        try? modelContext.save()
        dismiss()
    }
}
