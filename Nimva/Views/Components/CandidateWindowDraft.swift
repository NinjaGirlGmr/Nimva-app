import Foundation

// Shared between AddEventView (defines the candidate list from scratch) and EditEventView
// (shows/overrides an already-set list) — the plain editable draft shape backing #79's
// candidate time windows, kept separate from CandidateWindowService.Window (which is the
// read-only, already-resolved pairing the scoring algorithm itself works with).
struct CandidateWindowDraft: Identifiable {
    let id = UUID()
    var start: Date
    var end: Date
}

// Short "8:00 AM – 8:30 AM" style range text, shared by both screens' candidate rows — and
// by EventCard's own fixed-event subtitle, which used to have its own near-identical copy
// with a visible style mismatch (no spaces around the dash) before this was extracted.
func formattedWindowRange(_ start: Date, _ end: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
}
