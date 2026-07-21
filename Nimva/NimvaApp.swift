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

        // Skip CloudKit when the test runner is hosting the app — SwiftData's CloudKit
        // init can trap (not throw) when iCloud isn't available, crashing the test process
        // before any test connects. In-memory is fine for unit tests.
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
        let modelConfiguration: ModelConfiguration
        if isRunningTests {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.dev.hailey.nimva.Nimva")
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Persistent store failed — usually a schema migration error or CloudKit unavailable.
            // In DEBUG: fall back to in-memory so the app stays runnable while we diagnose.
            // In release: wipe the incompatible store, then try without CloudKit so the app
            //   launches even if the container isn't reachable (e.g. no iCloud on this device,
            //   or CloudKit schema not yet deployed to production). Sync resumes on next launch
            //   once the container becomes available.
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
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
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
