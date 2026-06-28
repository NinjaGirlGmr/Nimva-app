import SwiftUI
import SwiftData

// Root tab container.
// HomeView handles the Home tab; Plan, Insights, and Me are stubs for now.
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WeekGenerationView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            PlaceholderTab(title: "Insights", icon: "sparkles")
                .tabItem {
                    Label("Insights", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Me", systemImage: "person.fill")
                }
        }
        // Dark background bleeds through the tab bar area
        .background(NimvaColors.background)
        .tint(NimvaColors.purplePrimary)
    }
}

// Temporary placeholder used for tabs we haven't built yet.
// SwiftUI requires each tab to have a view — this keeps it compiling.
private struct PlaceholderTab: View {
    let title: String
    let icon: String

    var body: some View {
        ZStack {
            NimvaColors.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(NimvaColors.textMuted)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NimvaColors.textMuted)
                Text("Coming soon")
                    .font(.system(size: 13))
                    .foregroundStyle(NimvaColors.textMuted.opacity(0.6))
            }
        }
    }
}
