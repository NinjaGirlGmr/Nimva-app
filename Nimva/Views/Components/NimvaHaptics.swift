import UIKit

// Haptic feedback for Nimva — all calls go through here so:
//   1. The Settings "Sounds & haptics" toggle is always respected
//   2. The style and intensity is consistent across the whole app
//
// UIKit's feedback generators are used directly because SwiftUI
// doesn't expose haptics. These are safe to call from any view.

enum NimvaHaptics {

    // Read the user's preference straight from UserDefaults.
    // Defaults to true if the key hasn't been set yet (first launch).
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsHapticsEnabled") as? Bool ?? true
    }

    // Light tap — energy chip selection, day strip navigation, toggle switches
    static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Medium tap — primary button presses, confirming a selection
    static func medium() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // Success — approving a week, finishing onboarding, completing a check-in
    // Produces the distinctive double-tap success pattern iOS users recognise
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // Warning — heavy day detected, flex events couldn't be placed
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // Selection tick — scrolling through options, picker value changes
    // Lighter and faster than .light() — meant for rapid sequential feedback
    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
