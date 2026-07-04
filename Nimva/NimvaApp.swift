import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Single ProService instance shared across the whole app via environment.
    // Created here so subscription state survives tab switches.
    @State private var proService = ProService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Event.self, WeekCache.self])

        // CloudKit sync: once your Apple Developer account is enrolled and the
        // CloudKit capability is added in project settings, replace the
        // ModelConfiguration below with:
        //
        //   ModelConfiguration(
        //       schema: schema,
        //       isStoredInMemoryOnly: false,
        //       cloudKitDatabase: .private("iCloud.com.yourname.nimva")
        //   )
        //
        // Auth is handled automatically — CloudKit uses the device's iCloud account.
        // No Sign in with Apple or custom auth layer needed.
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Persistent store failed (e.g. schema migration error on simulator).
            // In DEBUG, fall back to an in-memory store so the app stays runnable
            // while we diagnose. In release this is a hard crash — a corrupt store
            // that can't be recovered should be surfaced, not silently discarded.
            #if DEBUG
            print("⚠️ SwiftData: persistent store failed (\(error)). Falling back to in-memory store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .preferredColorScheme(.dark)
                    .environment(proService)
            } else {
                OnboardingView()
                    .preferredColorScheme(.dark)
                    .environment(proService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
