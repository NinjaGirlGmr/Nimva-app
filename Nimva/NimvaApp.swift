import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"

    // Single ProService instance shared across the whole app via environment.
    // Created here so subscription state survives tab switches.
    @State private var proService = ProService()

    // Converts the stored string to SwiftUI's ColorScheme type.
    // nil means follow the system setting (the default).
    private var resolvedColorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .preferredColorScheme(resolvedColorScheme)
                    .environment(proService)
            } else {
                OnboardingView()
                    .preferredColorScheme(resolvedColorScheme)
                    .environment(proService)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
