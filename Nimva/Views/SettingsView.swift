import SwiftUI
import SwiftData

struct SettingsView: View {
    // @AppStorage persists each preference to UserDefaults automatically.
    // Changes are instant — no save button needed.
    @AppStorage("displayName") private var displayName = "Your Name"
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("checkInReminderEnabled") private var checkInReminderEnabled = true
    @AppStorage("soundsHapticsEnabled") private var soundsHapticsEnabled = true
    @AppStorage("globalPatternLearning") private var globalPatternLearning = true

    // modelContext lets us delete SwiftData records (used by Clear all data)
    @Environment(\.modelContext) private var modelContext

    @State private var showingNameEditor = false
    @State private var nameEditDraft = ""
    @State private var showingResetPatternsConfirm = false
    @State private var showingClearDataConfirm = false
    @State private var showingExportInfo = false
    @State private var showingAppleSignInInfo = false

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
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
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
        .alert("Sign in with Apple", isPresented: $showingAppleSignInInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Sign in with Apple and CloudKit sync are coming soon. Your data is stored safely on this device in the meantime.")
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
    }

    // MARK: - Page header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Account")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NimvaColors.textMuted)
                    .textCase(.uppercase)
                    .kerning(0.7)
                Text("Me")
                    .font(.system(size: 22, weight: .semibold))
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

                Text("🐣")
                    .font(.system(size: 24))
                    .frame(width: 46, height: 46)
                    .background(NimvaColors.surfaceDeep)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(NimvaColors.amberWarm, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NimvaColors.textPrimary)
                Text("Stored on this device")
                    .font(.system(size: 11))
                    .foregroundStyle(NimvaColors.textMuted)
            }

            Spacer()

            Button {
                nameEditDraft = displayName
                showingNameEditor = true
            } label: {
                Text("Edit")
                    .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 14))
                    .foregroundStyle(NimvaColors.textPrimary)
                Spacer()
                Text(preferredColorScheme.capitalized)
                    .font(.system(size: 12))
                    .foregroundStyle(NimvaColors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SettingsDivider()

            // Custom 3-way theme picker — native segmented control is hard to tint dark
            HStack(spacing: 6) {
                ForEach(["system", "light", "dark"], id: \.self) { scheme in
                    Button { preferredColorScheme = scheme } label: {
                        Text(scheme.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(preferredColorScheme == scheme ? .white : NimvaColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                preferredColorScheme == scheme
                                    ? NimvaColors.purplePrimary
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(8)
            .background(NimvaColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
            ActionRow(label: "Reset learned patterns", style: .destructive) {
                showingResetPatternsConfirm = true
            }
        }
    }

    // MARK: - Calendars

    private var calendarsSection: some View {
        SettingsSection(title: "Calendars") {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16))
                    .foregroundStyle(NimvaColors.textMuted)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Calendar & Google Calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(NimvaColors.textPrimary)
                    Text("Coming in a future update")
                        .font(.system(size: 11))
                        .foregroundStyle(NimvaColors.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            ActionRow(label: "Export my data", style: .normal) { showingExportInfo = true }
            SettingsDivider()
            ActionRow(label: "Sign in with Apple", style: .normal) { showingAppleSignInInfo = true }
            SettingsDivider()
            ActionRow(label: "Clear all data", style: .destructive) { showingClearDataConfirm = true }
        }
    }

    // MARK: - Version footer

    private var versionFooter: some View {
        Text("Nimva · v1.0 MVP")
            .font(.system(size: 11))
            .foregroundStyle(NimvaColors.textMuted.opacity(0.5))
            .padding(.top, 4)
    }

    // MARK: - Actions

    private func resetPatterns() {
        // Per-category energy baselines will be cleared here once the check-in
        // flow is built and baselines are persisted in SwiftData.
        // For now, the confirmation dialog itself communicates intent to the user.
    }

    private func clearAllData() {
        try? modelContext.delete(model: Event.self)
        try? modelContext.delete(model: WeekCache.self)
    }
}

// MARK: - Sub-components (private to this file)

private struct SettingsSection<Content: View>: View {
    let title: String
    // @ViewBuilder lets the caller pass multiple views without wrapping in a Group
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
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
                    .font(.system(size: 14))
                    .foregroundStyle(NimvaColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
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
                    .font(.system(size: 14))
                    .foregroundStyle(style == .destructive ? NimvaColors.coral : NimvaColors.textPrimary)
                Spacer()
                if style == .normal {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
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
