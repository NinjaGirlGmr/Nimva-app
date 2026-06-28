import SwiftUI
import SwiftData

@main
struct NimvaApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Set to true the first time the user either signs in or explicitly skips.
    // Once true, the sign-in screen never appears again.
    @AppStorage("hasSeenSignInPrompt") private var hasSeenSignInPrompt = false
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"

    // @State on a reference type makes AuthService's @Observable changes drive re-renders.
    // .environment() shares it with all child views.
    @State private var authService = AuthService()

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
            Group {
                if authService.authState == .unknown {
                    // Brief loading state while checkCredentialState() runs on launch.
                    // Typically resolves in under 200ms so no spinner needed.
                    NimvaColors.background.ignoresSafeArea()
                } else if !hasSeenSignInPrompt {
                    SignInView()
                } else if !hasCompletedOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                }
            }
            .preferredColorScheme(resolvedColorScheme)
            .environment(authService)
            // Verify the stored Apple credential on every cold launch.
            // Sets authState from .unknown to .signedIn or .anonymous.
            .task { await authService.checkCredentialState() }
        }
        .modelContainer(sharedModelContainer)
    }
}
