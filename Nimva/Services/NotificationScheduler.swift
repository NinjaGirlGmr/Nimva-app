import Foundation
import UserNotifications
import SwiftData

// A key that's never been written returns false from UserDefaults.standard.bool(forKey:) by
// default, which would silently disagree with an @AppStorage property whose declared default
// is true — this reads it the same way @AppStorage's own default would. Shared here (not
// duplicated per call site) since NimvaHaptics.swift already needed the identical pattern for
// "soundsHapticsEnabled" before this file existed.
extension UserDefaults {
    func defaultTrueBool(forKey key: String) -> Bool {
        object(forKey: key) as? Bool ?? true
    }
}

// Reads the three notification toggles from UserDefaults directly (not through @AppStorage,
// since this needs to be readable from outside a View).
enum NotificationPreferences {
    static let dailyNudgesKey = "dailyEnergyNudgesEnabled"
    static let checkInReminderKey = "checkInReminderEnabled"
    static let newWeekReminderKey = "newWeekReminderEnabled"

    static var dailyNudgesEnabled: Bool { UserDefaults.standard.defaultTrueBool(forKey: dailyNudgesKey) }
    static var checkInReminderEnabled: Bool { UserDefaults.standard.defaultTrueBool(forKey: checkInReminderKey) }
    static var newWeekReminderEnabled: Bool { UserDefaults.standard.defaultTrueBool(forKey: newWeekReminderKey) }

    /// True when every toggle is off — used to skip even requesting notification permission
    /// for a user who's opted out of all of it.
    static var allDisabled: Bool {
        !dailyNudgesEnabled && !checkInReminderEnabled && !newWeekReminderEnabled
    }
}

// Thin wrapper around UNUserNotificationCenter — NotificationService (a separate file) decides
// what to say and when; this just talks to the system framework, matching the existing pattern
// of keeping system-API wrappers minimal and pushing logic somewhere testable (see ProService,
// CalendarImportService).
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()
    private override init() {}

    /// Called once at launch (NimvaApp.init) so a nudge that happens to fire while the app is
    /// already open still shows a banner — without this, UIKit/SwiftUI's default is to
    /// silently swallow a notification whose app is in the foreground, which for something
    /// as infrequent as these would likely just look like it never fired at all.
    func registerAsDelegate() {
        center.delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private let center = UNUserNotificationCenter.current()
    // Tracks the most recent reschedule so a fresh call can cancel a still-running older one
    // instead of letting two overlap — see reschedule's doc comment.
    private var inFlightTask: Task<Void, Never>?

    /// Requests permission only if never asked before — never re-prompts once the user has
    /// answered (denied or allowed), matching standard iOS notification etiquette. Returns
    /// whether notifications can actually be delivered right now.
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Cancels this specific week's previously-scheduled notifications (identified by the
    /// same prefix NotificationService.identifierPrefix produces), then schedules the fresh
    /// set — so rebuilding a week with different heavy/light days doesn't leave stale
    /// notifications from an earlier build still pending. Silently does nothing if every
    /// toggle is off, or if the user has never granted (or has denied) permission — this is
    /// meant to degrade quietly, never surface a system permission prompt outside of a
    /// deliberate "turn a toggle on" moment.
    ///
    /// Cooperatively cancellable: rescheduleForCurrentWeek cancels any still-running call to
    /// this before starting a new one, and this checks Task.isCancelled at each await point so
    /// a superseded call stops making changes instead of racing the newer one to completion —
    /// without this, a rapid double-trigger (e.g. two quick "Redo" taps) could have an older
    /// call's cancel-then-add sequence interleave with a newer one's and wipe out whichever
    /// finished last.
    func reschedule(for snapshot: NotificationService.Snapshot) async {
        guard !NotificationPreferences.allDisabled else {
            await cancelWeek(snapshot.weekStartDate)
            return
        }
        guard await requestAuthorizationIfNeeded(), !Task.isCancelled else { return }

        // Awaited — critical that the stale set is actually gone before scheduling the fresh
        // one starts, not just requested. This used to fire-and-forget via the
        // completion-handler API, which could let a late-arriving cancellation wipe out
        // notifications this same call had just finished adding.
        await cancelWeek(snapshot.weekStartDate)
        guard !Task.isCancelled else { return }

        let specs = NotificationService.specs(
            for: snapshot,
            dailyNudgesEnabled: NotificationPreferences.dailyNudgesEnabled,
            checkInReminderEnabled: NotificationPreferences.checkInReminderEnabled,
            newWeekReminderEnabled: NotificationPreferences.newWeekReminderEnabled
        )
        for spec in specs {
            guard !Task.isCancelled else { return }
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: spec.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: spec.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Cancels every pending notification tagged with this week's identifier prefix. Uses the
    /// async pendingNotificationRequests() overload specifically so callers can await the
    /// removal actually happening, rather than the completion-handler variant returning
    /// immediately while the real work finishes on its own schedule.
    func cancelWeek(_ weekStart: Date) async {
        let prefix = NotificationService.identifierPrefix(for: weekStart)
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !stale.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: stale)
    }

    /// Cancels every one of Nimva's scheduled notifications — used when the user turns every
    /// toggle off, so disabling doesn't just stop *future* scheduling but also clears whatever
    /// was already queued up. Also cancels any still-running reschedule() so that older call
    /// can't turn around and re-add notifications after this has just cleared them.
    func cancelAll() {
        inFlightTask?.cancel()
        center.removeAllPendingNotificationRequests()
    }

    /// Convenience entry point for the UI layer: looks up the current week's cache and, if one
    /// exists, reschedules its notifications. Called after every regenerate() that builds the
    /// current week (weekOffset 0) — Build my week/Redo, delete/undo-delete recompute, and
    /// post-calendar-import recompute.
    ///
    /// Builds the Snapshot synchronously, on the caller's own thread, before ever entering the
    /// async Task below — reschedule/cancelWeek cross several `await` suspension points, and a
    /// live WeekCache (a SwiftData model reference) isn't safe to keep reading after one: the
    /// context that owns it can mutate or save concurrently on the main thread while this task
    /// is suspended. The Snapshot is a plain, Sendable copy taken up front specifically so
    /// nothing here ever touches the model object again once execution leaves this function.
    static func rescheduleForCurrentWeek(context: ModelContext) {
        guard let caches = try? context.fetch(FetchDescriptor<WeekCache>()),
              let cache = SchedulerService.currentWeekCache(from: caches)
        else { return }
        let snapshot = NotificationService.Snapshot(cache)
        shared.inFlightTask?.cancel()
        shared.inFlightTask = Task { await shared.reschedule(for: snapshot) }
    }
}
