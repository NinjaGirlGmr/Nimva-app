import SwiftUI

// Hex initializer — lets us write Color(hex: "100c28") anywhere
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Colors

// Contrast ratios against background (#100c28) — all must meet WCAG 2.1 AA (4.5:1 normal text, 3:1 UI components)
enum NimvaColors {
    static let background    = Color(hex: "100c28")
    static let surface       = Color(hex: "1e1850")
    static let surfaceDeep   = Color(hex: "181440")
    static let border        = Color(hex: "241a50")
    static let cardDark      = Color(hex: "1a1648")

    static let purplePrimary = Color(hex: "6c50d0")  // 3.34:1 — UI components only (buttons, icons, tabs)
    static let purpleMuted   = Color(hex: "2d2060")

    static let teal          = Color(hex: "1d9e75")  // 5.61:1 ✓ AA
    static let coral         = Color(hex: "e0825a")  // 6.79:1 ✓ AA — second flexible-event color (replaces blue)
    static let amber         = Color(hex: "ef9f27")  // 8.74:1 ✓ AA
    static let amberWarm     = Color(hex: "e0a458")  // Ember glow / spark

    static let textPrimary   = Color(hex: "e8e0ff")  // 14.96:1 ✓ AA — all essential content
    static let textSecondary = Color(hex: "a090d0")  //  6.69:1 ✓ AA — supporting content users need to read
    // Updated from #6050a0 (2.85:1 ✗) → #8878c8 (5.04:1 ✓) for WCAG AA compliance
    static let textMuted     = Color(hex: "8878c8")  //  5.04:1 ✓ AA — section labels, subtitles, meta-info
    // Reserve this for purely decorative text only (version footer, visual separators).
    // Never use for content a user needs to read — it fails AA at 2.85:1.
    static let textDecorative = Color(hex: "6050a0")

    // Heavy-day dot in the week strip — a load indicator, not an event color,
    // so it's exempt from the coral replacement rule
    static let heavyBlue     = Color(hex: "378add")

    // Alt energy palette — icon ring colours, all verified AA against background (#100c28)
    // Classic:  teal (#1d9e75, 5.61:1) / amber (#ef9f27, 8.74:1) / coral (#e0825a, 6.79:1)
    // Alt:      cyan (#3dcfb6, 9.66:1) / indigo (#9472e0, 5.20:1) / rose (#c45a9e, 4.95:1)
    // Note: #7c52d4 was the previous indigo at 3.63:1 — failed AA for badge text, replaced.
    static let altEnergyLight = Color(hex: "3dcfb6")
    static let altEnergyMixed = Color(hex: "9472e0")
    static let altEnergyHeavy = Color(hex: "c45a9e")

    static func energyLight(_ alt: Bool) -> Color { alt ? altEnergyLight : teal }
    static func energyMixed(_ alt: Bool) -> Color { alt ? altEnergyMixed : amber }
    static func energyHeavy(_ alt: Bool) -> Color { alt ? altEnergyHeavy : coral }
}

// MARK: - Typography

// Semantic font scale — each style scales with the user's Dynamic Type setting.
// Dynamic Type scaling is required for WCAG 1.4.4 (Resize Text, Level AA).
// Use these instead of hardcoded .system(size:) values in new code.
enum NimvaFont {
    // Display / headings
    static let largeDisplay = Font.system(.largeTitle,   weight: .bold)    // onboarding hero numbers — ~34pt
    static let display      = Font.system(.title,        weight: .bold)    // large emphasis text — ~28pt
    static let greeting     = Font.system(.title2,       weight: .semibold)// "Your week" — ~22pt
    static let closingTitle = Font.system(.title2,       weight: .bold)    // check-in done headline — ~22pt
    static let pageTitle    = Font.system(.title3,       weight: .semibold)// section titles — ~20pt
    static let pageTitleBold = Font.system(.title3,      weight: .bold)    // emphasis headings — ~20pt

    // Body
    static let headline     = Font.system(.headline)                       // prominent body text — ~17pt semibold
    static let callout      = Font.system(.callout)                        // slightly-above-body — ~16pt
    static let calloutMed   = Font.system(.callout,      weight: .medium)  // medium callout — ~16pt
    static let calloutSemi  = Font.system(.callout,      weight: .semibold)// semibold callout — ~16pt
    static let cardTitle    = Font.system(.subheadline,  weight: .medium)  // card headers — ~15pt
    static let button       = Font.system(.subheadline,  weight: .semibold)// CTA button labels — ~15pt
    static let body         = Font.system(.footnote)                       // event names, descriptions — ~13pt
    static let bodyMedium   = Font.system(.footnote,     weight: .medium)  // medium-weight body — ~13pt
    static let bodySemi     = Font.system(.footnote,     weight: .semibold)// semibold body — ~13pt
    static let bodyBold     = Font.system(.footnote,     weight: .bold)    // bold body — ~13pt

    // Supporting
    static let sectionLabel = Font.system(.caption,      weight: .medium)  // "NOTIFICATIONS" — ~12pt
    static let captionSemi  = Font.system(.caption,      weight: .semibold)// semibold caption — ~12pt
    static let chip         = Font.system(.caption2,     weight: .medium)  // energy badges — ~11pt
    static let micro        = Font.system(.caption2)                       // timestamps, meta — ~11pt
}

// MARK: - Layout

// Single source of truth for spacing, radii, and accessibility sizing.
// All spacing values are multiples of the 8pt grid (use 4pt only for fine-tuning).
enum NimvaLayout {
    static let gridUnit: CGFloat = 8

    // Screen and card padding
    static let screenPadding: CGFloat = 20
    static let cardPadding:   CGFloat = 16

    // Corner radii (from design spec: 12-14 for cards, 38-40 for large frames)
    static let cardRadius:    CGFloat = 14
    static let inputRadius:   CGFloat = 12
    static let chipRadius:    CGFloat = 99  // effectively a capsule
    static let frameRadius:   CGFloat = 38

    // WCAG 2.5.5 + Apple HIG: every interactive element needs at least 44×44pt.
    // Apply .minTouchTarget() to any small button, icon, or chip.
    static let minTouchTarget: CGFloat = 44

    // Section label letter-spacing — 0.07em at ~10pt ≈ 0.7pt
    static let sectionKerning: CGFloat = 0.7
}
