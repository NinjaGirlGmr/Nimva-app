import SwiftUI
import UIKit

// Minimal UIActivityViewController wrapper — SwiftUI's own ShareLink can't be triggered
// imperatively (it only presents from a direct tap on itself), but #32's export flow needs to
// write temp files first and only then show the share sheet, so a `.sheet(isPresented:)`-driven
// UIKit bridge is the simpler path here.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
