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
        if isRunningTests {
            return try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }

        // CloudKit private database for sync. Fall back to local-only if the container is
        // unavailable (iCloud not signed in, schema not yet deployed, etc.). Sync resumes
        // automatically on the next launch once the container becomes reachable.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.dev.hailey.nimva.Nimva")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let dir {
                let store = dir.appendingPathComponent("default.store")
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: store.path + suffix))
                }
            }
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
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
