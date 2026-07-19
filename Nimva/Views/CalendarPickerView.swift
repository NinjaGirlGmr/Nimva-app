import SwiftUI

struct CalendarPickerView: View {
    let calendars: [CalendarImportService.CalendarInfo]
    @Binding var selectedIDs: Set<String>
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                NimvaColors.background.ignoresSafeArea()

                if calendars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(NimvaFont.largeDisplay)
                            .foregroundStyle(NimvaColors.textMuted)
                        Text("No calendars found")
                            .font(NimvaFont.cardTitle)
                            .foregroundStyle(NimvaColors.textPrimary)
                        Text("Make sure you have at least one calendar set up in Apple Calendar.")
                            .font(NimvaFont.body)
                            .foregroundStyle(NimvaColors.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        Section {
                            ForEach(calendars) { calendar in
                                Button {
                                    if selectedIDs.contains(calendar.id) {
                                        selectedIDs.remove(calendar.id)
                                    } else {
                                        selectedIDs.insert(calendar.id)
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(calendar.color)
                                            .frame(width: 12, height: 12)
                                        Text(calendar.title)
                                            .font(NimvaFont.callout)
                                            .foregroundStyle(NimvaColors.textPrimary)
                                        Spacer()
                                        if selectedIDs.contains(calendar.id) {
                                            Image(systemName: "checkmark")
                                                .font(NimvaFont.bodySemi)
                                                .foregroundStyle(NimvaColors.purplePrimary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(minHeight: 44)
                            }
                        } header: {
                            Text("Nimva will only pull timed events from the calendars you select.")
                                .font(.system(.caption))
                                .foregroundStyle(NimvaColors.textMuted)
                                .textCase(nil)
                        }
                        .listRowBackground(NimvaColors.cardDark)
                    }
                    .scrollContentBackground(.hidden)
                    .background(NimvaColors.background)
                }
            }
            .navigationTitle("Choose calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Select all") {
                        selectedIDs = Set(calendars.map(\.id))
                    }
                    .foregroundStyle(NimvaColors.textMuted)
                    .font(NimvaFont.callout)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .font(.system(.callout, weight: .semibold))
                }
            }
        }
    }
}
