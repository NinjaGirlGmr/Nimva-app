import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Single ProService instance shared across the whole app via environment.
    // Created here so subscription state survives tab switches.
    @State private var proService = ProService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Event.self, WeekCache.self, Intention.self])

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
            // Persistent store failed — usually a schema migration error after a model change.
            // In DEBUG: fall back to in-memory so the app stays runnable while we diagnose.
            // In release: wipe the incompatible store and recreate rather than crashing.
            //   → TestFlight testers lose local data on this update, but the app stays open.
            //   → Before App Store release, replace with a proper VersionedSchema migration plan.
            #if DEBUG
            print("⚠️ SwiftData: persistent store failed (\(error)). Falling back to in-memory store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
            #else
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let dir {
                let store = dir.appendingPathComponent("default.store")
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: store.path + suffix))
                }
            }
            return try! ModelContainer(for: schema, configurations: [modelConfiguration])
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
