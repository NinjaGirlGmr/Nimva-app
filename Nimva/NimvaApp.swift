import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"

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
        // Until then, data is stored locally only.
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
            } else {
                OnboardingView()
                    .preferredColorScheme(resolvedColorScheme)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
