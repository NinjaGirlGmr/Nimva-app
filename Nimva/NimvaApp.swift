import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Single ProService instance shared across the whole app via environment.
    // Created here so subscription state survives tab switches.
    @State private var proService = ProService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: NimvaSchemaV1.self)

        // Skip CloudKit when the test runner is hosting the app — SwiftData's CloudKit
        // init can trap (not throw) when iCloud isn't available, crashing the test process
        // before any test connects. In-memory is fine for unit tests.
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
        if isRunningTests {
            return try! ModelContainer(
                for: schema,
                migrationPlan: NimvaMigrationPlan.self,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        }

        // CloudKit private database for sync. Sync resumes automatically on a later launch
        // once the container becomes reachable, as long as this first attempt succeeds.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.dev.hailey.nimva.Nimva")
        )
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: NimvaMigrationPlan.self,
            configurations: [cloudConfig]
        ) {
            return container
        }

        // CloudKit unreachable (iCloud not signed in, prod schema not deployed yet, etc.) —
        // fall back to the SAME store file without CloudKit, so existing local data survives.
        // This still runs the migration plan, so a model change alone won't land here either.
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(
            for: schema,
            migrationPlan: NimvaMigrationPlan.self,
            configurations: [localConfig]
        ) {
            return container
        }

        // Last resort: the store itself is unreadable (corruption, not just missing CloudKit
        // or a migratable schema change). Only now is it safe to delete and start fresh.
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let dir {
            let store = dir.appendingPathComponent("default.store")
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: store.path + suffix))
            }
        }
        return try! ModelContainer(
            for: schema,
            migrationPlan: NimvaMigrationPlan.self,
            configurations: [localConfig]
        )
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
