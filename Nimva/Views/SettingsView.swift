import SwiftUI
import SwiftData
import EventKit

struct SettingsView: View {
    // @AppStorage persists each preference to UserDefaults automatically.
    // Changes are instant — no save button needed.
    @Query private var events: [Event]

    @AppStorage("displayName") private var displayName = "Your Name"
    @AppStorage("lastCalendarImportDate") private var lastCalendarImportDate: Double = 0
    @AppStorage("checkInReminderEnabled") private var checkInReminderEnabled = true
    @AppStorage("soundsHapticsEnabled") private var soundsHapticsEnabled = true
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true
    @AppStorage("energyAnchorLabel") private var energyAnchorLabel = ""
    @AppStorage("useAltEnergyPalette") private var useAltEnergyPalette = false
    @AppStorage("selectedCalendarIDsCSV") private var selectedCalendarIDsCSV: String = ""

    private var selectedCalendarIDs: Set<String> {
        Set(selectedCalendarIDsCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    // modelContext lets us delete SwiftData records (used by Clear all data)
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var showingNameEditor = false
    @State private var nameEditDraft = ""
    @State private var ekStore = EKEventStore()
    @State private var isCalendarAuthorized = CalendarImportService.isAuthorized
    @State private var availableCalendars: [CalendarImportService.CalendarInfo] = []
    @State private var showingCalendarPicker = false
    @State private var showingCalendarImport = false
    @State private var showingCalendarDenied = false
    @State private var calendarCandidates: [CalendarImportService.ImportCandidate] = []
    @State private var showingAnchorEditor = false
    @State private var anchorEditDraft = ""
    @State private var showingResetPatternsConfirm = false
    @State private var showingClearDataConfirm = false
    @State private var showingExportInfo = false
    @State private var showingRecomputeError = false
    @State private var showingOnboarding = false
    #if DEBUG
    @State private var showingSeedConfirm = false
    @State private var seedMessage: String? = nil
    #endif

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    pageHeader
                    profileCard
                    appearanceSection
                    notificationsSection
                    energyLearningSection
                    calendarsSection
                    accountSection
                    helpSection
                    versionFooter
                    #if DEBUG
                    developerSection
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        // Energy anchor editor
        .alert("Pretty draining anchor", isPresented: $showingAnchorEditor) {
            TextField("e.g. back-to-back classes", text: $anchorEditDraft)
            Button("Save") {
                energyAnchorLabel = anchorEditDraft.trimmingCharacters(in: .whitespaces)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Shown as a hint under \"Pretty Draining\" when you add events.")
        }
        // Name editor
        .alert("Edit your name", isPresented: $showingNameEditor) {
            TextField("Name", text: $nameEditDraft)
                .autocorrectionDisabled()
            Button("Save") {
                let trimmed = nameEditDraft.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { displayName = trimmed }
            }
            Button("Cancel", role: .cancel) { }
        }
        // Info alerts for stubbed features
        .alert("Export my data", isPresented: $showingExportInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Data export is coming in a future update. Your events and schedule history will be downloadable as a file.")
        }
        // Destructive confirmations use confirmationDialog so the OS shows the action sheet
        .confirmationDialog("Reset learned patterns?", isPresented: $showingResetPatternsConfirm, titleVisibility: .visible) {
            Button("Reset patterns", role: .destructive) { resetPatterns() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Nimva will start learning your energy patterns from scratch. Your events and schedule are not affected.")
        }
        .confirmationDialog("Clear all data?", isPresented: $showingClearDataConfirm, titleVisibility: .visible) {
            Button("Clear all data", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes all your events and schedule history. This cannot be undone.")
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarPickerView(
                calendars: availableCalendars,
                selectedIDs: Binding(
                    get: { selectedCalendarIDs },
                    set: { selectedCalendarIDsCSV = $0.joined(separator: ",") }
                ),
                onDone: { showingCalendarPicker = false }
            )
        }
        .sheet(isPresented: $showingCalendarImport) {
            CalendarImportView(
                candidates: calendarCandidates,
                onImport: { selected in
                    CalendarImportService.insert(selected, into: modelContext)
                    lastCalendarImportDate = Date().timeIntervalSince1970
                    showingCalendarImport = false
                    recomputeAfterImport()
                },
                onCancel: { showingCalendarImport = false }
            )
        }
        .alert("Calendar Access Needed", isPresented: $showingCalendarDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Nimva needs calendar access to import your events. Enable it in Settings › Privacy › Calendars.")
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .alert("Couldn't update schedule", isPresented: $showingRecomputeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Events were imported, but the schedule couldn't be rebuilt. Try regenerating your week manually.")
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preferences")
                    .font(NimvaFont.chip)
                    .foregroundStyle(NimvaColors.textMuted)
                    .textCase(.uppercase)
                    .kerning(0.7)
                Text("Settings")
                    .font(NimvaFont.greeting)
                    .foregroundStyle(NimvaColors.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: 14) {
            // Ember avatar — same warm-glow treatment as the home screen card
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [NimvaColors.amberWarm.opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 26
                    ))
                    .frame(width: 58, height: 58)

                EmberView(expression: .calm, size: .mini)
                    .frame(width: 46, height: 46)
                    .background(NimvaColors.surfaceDeep)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NimvaColors.amberWarm, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(NimvaFont.calloutSemi)
                    .foregroundStyle(NimvaColors.textPrimary)
                Text("Stored on this device")
                    .font(NimvaFont.micro)
                    .foregroundStyle(NimvaColors.textMuted)
            }

            Spacer()

            Button {
                nameEditDraft = displayName
                showingNameEditor = true
            } label: {
                Text("Edit")
                    .font(NimvaFont.sectionLabel)
                    .foregroundStyle(NimvaColors.purplePrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NimvaColors.purplePrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(NimvaColors.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            HStack {
                Text("Theme")
                    .font(NimvaFont.callout)
                    .foregroundStyle(NimvaColors.textPrimary)
                Spacer()
                Text("Dark")
                    .font(.system(.caption))
                    .foregroundStyle(NimvaColors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SettingsDivider()

            ToggleRow(
                label: "Alt energy colours",
                subtitle: "Cyan / indigo / rose instead of teal / amber / coral",
                isOn: $useAltEnergyPalette
            )

            Text("Light mode coming in a future update.")
                .font(NimvaFont.micro)
                .foregroundStyle(NimvaColors.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            ToggleRow(label: "Weekly check-in reminder", subtitle: "Sunday evenings", isOn: $checkInReminderEnabled)
            SettingsDivider()
            ToggleRow(label: "Sounds & haptics", subtitle: "In-app feedback on interactions", isOn: $soundsHapticsEnabled)
        }
    }

    // MARK: - Energy & Learning

    private var energyLearningSection: some View {
        SettingsSection(title: "Energy & Learning") {
            ToggleRow(label: "Pattern learning", subtitle: "Learn from your weekly check-ins", isOn: $globalPatternLearning)
            SettingsDivider()
            Button {
                anchorEditDraft = energyAnchorLabel
                showingAnchorEditor = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pretty draining anchor")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.textPrimary)
                        Text(energyAnchorLabel.isEmpty ? "Not set — tap to add" : "\"\(energyAnchorLabel)\"")
                            .font(NimvaFont.micro)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(NimvaFont.chip)
                        .foregroundStyle(NimvaColors.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            SettingsDivider()
            ActionRow(label: "Reset learned patterns", style: .destructive) {
                showingResetPatternsConfirm = true
            }
        }
    }

    // MARK: - Calendars

    private var calendarsSection: some View {
        SettingsSection(title: "Calendars") {
            if !isCalendarAuthorized {
                Button { connectCalendar() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar.badge.plus")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.teal)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Apple Calendar")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textPrimary)
                            Text("Grant access to import your events")
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(NimvaFont.chip)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Calendar picker row
                Button { openCalendarPicker() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.purplePrimary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendars")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textPrimary)
                            Text(calendarSelectionSummary)
                                .font(NimvaFont.micro)
                                .foregroundStyle(NimvaColors.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(NimvaFont.chip)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SettingsDivider()

                // Refresh / import row
                Button { refreshCalendar() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.clockwise")
                            .font(NimvaFont.callout)
                            .foregroundStyle(NimvaColors.teal)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh from Calendar")
                                .font(NimvaFont.callout)
                                .foregroundStyle(NimvaColors.textPrimary)
                            if lastCalendarImportDate > 0 {
                                Text("Last imported \(Date(timeIntervalSince1970: lastCalendarImportDate), style: .relative) ago")
                                    .font(NimvaFont.micro)
                                    .foregroundStyle(NimvaColors.textMuted)
                            } else {
                                Text("Pull this week's events into Nimva")
                                    .font(NimvaFont.micro)
                                    .foregroundStyle(NimvaColors.textMuted)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(NimvaFont.chip)
                            .foregroundStyle(NimvaColors.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calendarSelectionSummary: String {
        let ids = selectedCalendarIDs
        if ids.isEmpty { return "No calendars selected — tap to choose" }
        let matched = availableCalendars.filter { ids.contains($0.id) }.map(\.title)
        if matched.isEmpty { return "\(ids.count) selected" }
        if matched.count <= 2 { return matched.joined(separator: ", ") }
        return "\(matched[0]), \(matched[1]) +\(matched.count - 2) more"
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            ActionRow(label: "Export my data", style: .normal) { showingExportInfo = true }
            SettingsDivider()
            // iCloud sync uses the device's iCloud account automatically via CloudKit.
            // No separate sign-in flow needed.
            HStack(spacing: 14) {
                Image(systemName: "icloud.fill")
                    .font(.system(.subheadline))
                    .foregroundStyle(NimvaColors.textMuted)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud sync")
                        .font(NimvaFont.callout)
                        .foregroundStyle(NimvaColors.textPrimary)
                    Text("Uses your iCloud account automatically")
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            SettingsDivider()
            ActionRow(label: "Clear all data", style: .destructive) { showingClearDataConfirm = true }
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        SettingsSection(title: "Help") {
            ActionRow(label: "How Nimva works", style: .normal) {
                showingOnboarding = true
            }
            SettingsDivider()
            ActionRow(label: "Privacy Policy", style: .normal) {
                if let url = URL(string: "https://ninjagirlgmr.github.io/Nimva-app/privacy.html") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Version footer

    private var versionFooter: some View {
        Text("Nimva · v1.0 MVP")
            .font(NimvaFont.micro)
            .foregroundStyle(NimvaColors.textMuted.opacity(0.5))
            .padding(.top, 4)
    }

    // MARK: - Actions

    private func connectCalendar() {
        Task {
            let granted = await CalendarImportService.requestAccess(store: ekStore)
            await MainActor.run {
                if granted {
                    isCalendarAuthorized = true
                    availableCalendars = CalendarImportService.availableCalendars(store: ekStore)
                    // Pre-select all calendars on first connect
                    if selectedCalendarIDsCSV.isEmpty {
                        selectedCalendarIDsCSV = availableCalendars.map(\.id).joined(separator: ",")
                    }
                    showingCalendarPicker = true
                } else {
                    showingCalendarDenied = true
                }
            }
        }
    }

    private func openCalendarPicker() {
        availableCalendars = CalendarImportService.availableCalendars(store: ekStore)
        showingCalendarPicker = true
    }

    private func refreshCalendar() {
        let existing = Array(events)
        let ids = selectedCalendarIDs
        calendarCandidates = CalendarImportService.fetchCandidates(
            store: ekStore,
            existingEvents: existing,
            selectedCalendarIDs: ids
        )
        showingCalendarImport = true
    }

    private func recomputeAfterImport() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<Event>())
            try SchedulerService.regenerate(context: modelContext, events: all)
        } catch {
            showingRecomputeError = true
        }
    }

    private func resetPatterns() {
        // Clear learned per-category baselines from UserDefaults
        PatternService.shared.reset()

        // Clear check-in ratings from all WeekCache records so the
        // feedback loop restarts from scratch and the check-in banner
        // reappears on the home screen
        let caches = (try? modelContext.fetch(FetchDescriptor<WeekCache>())) ?? []
        for cache in caches {
            cache.checkInRating = nil
            cache.checkInHardestDayRawValue = nil
            cache.checkInCompletedAt = nil
        }
    }

    private func clearAllData() {
        try? modelContext.delete(model: Event.self)
        try? modelContext.delete(model: WeekCache.self)
    }

    // MARK: - Developer section (DEBUG only)

    #if DEBUG
    private var developerSection: some View {
        SettingsSection(title: "Developer Tools") {
            ActionRow(label: "Seed sample data", style: .normal) {
                showingSeedConfirm = true
            }
            SettingsDivider()
            ActionRow(label: "Clear seeded data", style: .destructive) {
                clearAllData()
                seedMessage = "All data cleared."
            }
            if let msg = seedMessage {
                Text(msg)
                    .font(NimvaFont.micro)
                    .foregroundStyle(NimvaColors.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .confirmationDialog("Seed sample data?", isPresented: $showingSeedConfirm, titleVisibility: .visible) {
            Button("Seed (replaces all data)", role: .destructive) {
                SeedService.seed(context: modelContext)
                seedMessage = "Seeded 12 events + 7 weeks of history."
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Replaces all existing events and week history with a realistic sample dataset. Tuesday will be consistently heavy to trigger Insights pattern callouts.")
        }
    }
    #endif
}

// MARK: - Sub-components (private to this file)

private struct SettingsSection<Content: View>: View {
    let title: String
    // @ViewBuilder lets the caller pass multiple views without wrapping in a Group
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(NimvaFont.chip)
                .foregroundStyle(NimvaColors.textMuted)
                .textCase(.uppercase)
                .kerning(0.7)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(NimvaColors.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// A 1pt horizontal line used between rows within a card
private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(NimvaColors.border)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

private struct ToggleRow: View {
    let label: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(NimvaFont.callout)
                    .foregroundStyle(NimvaColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(NimvaFont.micro)
                        .foregroundStyle(NimvaColors.textMuted)
                }
            }
            Spacer()
            // .tint sets the on-state color of the toggle switch
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NimvaColors.purplePrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private enum ActionStyle { case normal, destructive }

private struct ActionRow: View {
    let label: String
    let style: ActionStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(NimvaFont.callout)
                    .foregroundStyle(style == .destructive ? NimvaColors.coral : NimvaColors.textPrimary)
                Spacer()
                if style == .normal {
                    Image(systemName: "chevron.right")
                        .font(NimvaFont.chip)
                        .foregroundStyle(NimvaColors.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            // contentShape makes the whole row tappable, not just the text
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Event.self, WeekCache.self], inMemory: true)
}
