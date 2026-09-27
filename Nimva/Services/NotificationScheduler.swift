import Foundation
import UserNotifications
import SwiftData

// Reads the three notification toggles from UserDefaults directly (not through @AppStorage,
// since this needs to be readable from outside a View) with the same "default true" semantics
// Settings' @AppStorage declarations use — a key that's never been written returns false from
// UserDefaults.standard.bool(forKey:) by default, which would silently disagree with an
// @AppStorage property whose declared default is true, so that mismatch is handled explicitly
// here rather than assumed.
enum NotificationPreferences {
    static let dailyNudgesKey = "dailyEnergyNudgesEnabled"
    static let checkInReminderKey = "checkInReminderEnabled"
    static let newWeekReminderKey = "newWeekReminderEnabled"

    static var dailyNudgesEnabled: Bool { readDefaultTrue(dailyNudgesKey) }
    static var checkInReminderEnabled: Bool { readDefaultTrue(checkInReminderKey) }
    static var newWeekReminderEnabled: Bool { readDefaultTrue(newWeekReminderKey) }

    /// True when every toggle is off — used to skip even requesting notification permission
    /// for a user who's opted out of all of it.
    static var allDisabled: Bool {
        !dailyNudgesEnabled && !checkInReminderEnabled && !newWeekReminderEnabled
    }

    private static func readDefaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
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
    func reschedule(for cache: WeekCache) async {
        guard !NotificationPreferences.allDisabled else {
            cancelWeek(cache.weekStartDate)
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        cancelWeek(cache.weekStartDate)

        let specs = NotificationService.specs(
            for: cache,
            dailyNudgesEnabled: NotificationPreferences.dailyNudgesEnabled,
            checkInReminderEnabled: NotificationPreferences.checkInReminderEnabled,
            newWeekReminderEnabled: NotificationPreferences.newWeekReminderEnabled
        )
        for spec in specs {
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

    /// Cancels every pending notification tagged with this week's identifier prefix.
    func cancelWeek(_ weekStart: Date) {
        let prefix = NotificationService.identifierPrefix(for: weekStart)
        center.getPendingNotificationRequests { [center] requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !stale.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    /// Cancels every one of Nimva's scheduled notifications — used when the user turns every
    /// toggle off, so disabling doesn't just stop *future* scheduling but also clears whatever
    /// was already queued up.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Convenience entry point for the UI layer: looks up the current week's cache and, if one
    /// exists, reschedules its notifications. Called after every regenerate() that builds the
    /// current week (weekOffset 0) — Build my week/Redo, delete/undo-delete recompute, and
    /// post-calendar-import recompute.
    static func rescheduleForCurrentWeek(context: ModelContext) {
        guard let caches = try? context.fetch(FetchDescriptor<WeekCache>()),
              let cache = SchedulerService.currentWeekCache(from: caches)
        else { return }
        Task { await NotificationScheduler.shared.reschedule(for: cache) }
    }
}
