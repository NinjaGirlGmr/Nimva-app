import Foundation

// Shared three-tier vocabulary for "how heavy does this look" — used both for a single
// day's raw load and for a whole week's balance variance, so every load-related display
// in the app (day-strip dots, the day-load bar, the week's energy-balance bar) speaks the
// same visual language instead of each maintaining its own independent color scheme.
enum LoadSeverity {
    case light, moderate, heavy

    // A single day's raw load against the scheduler's own heavy-day threshold — ties every
    // consumer to the same boundary Scheduler.swift actually uses for "heavy," instead of
    // each view hardcoding its own copy of the number (which can silently drift out of sync
    // with the real threshold if it's ever tuned).
    static func forLoad(_ load: Double, heavyThreshold: Double = Scheduler.heavyDayThreshold) -> LoadSeverity {
        switch load {
        case ..<(heavyThreshold * 0.5): return .light
        case ..<heavyThreshold:         return .moderate
        default:                        return .heavy
        }
    }

    // A whole week's balance variance (WeekSchedule.balanceScore — lower is more balanced).
    // Breakpoints match the ones already used for the "Good spread" / "Some days are
    // heavier" / "Load is concentrated" copy in WeekGenerationView, so a bar colored from
    // this and the words sitting next to it can never disagree about the same week.
    static func forVariance(_ variance: Double) -> LoadSeverity {
        switch variance {
        case ..<0.4:  return .light
        case ..<0.66: return .moderate
        default:      return .heavy
        }
    }

    // Resolves to whichever of the user's three customizable Energy Colours hex strings
    // (Settings → Energy Colours) matches this tier.
    func hex(light: String, mixed: String, heavy: String) -> String {
        switch self {
        case .light:    return light
        case .moderate: return mixed
        case .heavy:    return heavy
        }
    }
}

// Smooth 0...1 fill for the "Energy balance" bar once a week is built — higher variance
// (less balanced) yields a smaller fill instead of the bar always sitting at 100% regardless
// of whether the week is actually balanced. Asymptotic rather than hard-clamped to 0, so even
// a genuinely lopsided week reads as "notably lower," not a jarring empty/judgmental bar —
// consistent with the app's honest-but-not-alarming tone.
func balanceBarFill(forVariance variance: Double) -> Double {
    1.0 / (1.0 + max(variance, 0) / 1.2)
}
