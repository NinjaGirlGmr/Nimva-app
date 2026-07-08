import Testing
import Foundation
@testable import Nimva

// All tests use a fixed base date — 2026-07-04 at noon — so that the
// date component preservation check is repeatable regardless of when the
// suite runs.
private let baseDate: Date = {
    var comps = DateComponents()
    comps.year = 2026; comps.month = 7; comps.day = 4
    comps.hour = 12; comps.minute = 0; comps.second = 0
    return Calendar.current.date(from: comps) ?? Date()
}()

private func h(_ hour: Int, _ minute: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
}

@Suite("parseTimeString — format variants")
struct TimeParsingFormatTests {

    @Test func twelve_hour_with_AM() {
        let result = parseTimeString("9:30 AM", relativeTo: baseDate)
        #expect(result == h(9, 30))
    }

    @Test func twelve_hour_with_PM() {
        let result = parseTimeString("2:45 PM", relativeTo: baseDate)
        #expect(result == h(14, 45))
    }

    @Test func twelve_hour_lowercase_am() {
        // "h:mma" format — no space
        let result = parseTimeString("9:30am", relativeTo: baseDate)
        #expect(result == h(9, 30))
    }

    @Test func twelve_hour_lowercase_pm() {
        let result = parseTimeString("2:45pm", relativeTo: baseDate)
        #expect(result == h(14, 45))
    }

    @Test func twenty_four_hour_format() {
        let result = parseTimeString("14:45", relativeTo: baseDate)
        #expect(result == h(14, 45))
    }

    @Test func twelve_hour_no_meridiem() {
        // "h:mm" format — ambiguous, but parseable
        let result = parseTimeString("9:30", relativeTo: baseDate)
        #expect(result != nil)
        if let r = result {
            let comps = Calendar.current.dateComponents([.minute], from: r)
            #expect(comps.minute == 30)
        }
    }

    @Test func hour_only_with_space_AM() {
        // "h a" format: "9 AM"
        let result = parseTimeString("9 AM", relativeTo: baseDate)
        #expect(result == h(9, 0))
    }

    @Test func hour_only_no_space_lowercase() {
        // "ha" format: "9am"
        let result = parseTimeString("9am", relativeTo: baseDate)
        #expect(result == h(9, 0))
    }

    @Test func midnight_represented_as_12AM() {
        let result = parseTimeString("12:00 AM", relativeTo: baseDate)
        #expect(result == h(0, 0))
    }

    @Test func noon_represented_as_12PM() {
        let result = parseTimeString("12:00 PM", relativeTo: baseDate)
        #expect(result == h(12, 0))
    }

    @Test func leading_whitespace_ignored() {
        let result = parseTimeString("  9:30 AM", relativeTo: baseDate)
        #expect(result == h(9, 30))
    }

    @Test func trailing_whitespace_ignored() {
        let result = parseTimeString("9:30 AM  ", relativeTo: baseDate)
        #expect(result == h(9, 30))
    }
}

@Suite("parseTimeString — date component preservation")
struct TimeParsingDatePreservationTests {

    @Test func year_preserved_from_base() {
        let result = parseTimeString("9:30 AM", relativeTo: baseDate)
        guard let r = result else { return #expect(Bool(false), "parse returned nil") }
        let comps = Calendar.current.dateComponents([.year], from: r)
        #expect(comps.year == 2026)
    }

    @Test func month_preserved_from_base() {
        let result = parseTimeString("9:30 AM", relativeTo: baseDate)
        guard let r = result else { return #expect(Bool(false), "parse returned nil") }
        let comps = Calendar.current.dateComponents([.month], from: r)
        #expect(comps.month == 7)
    }

    @Test func day_preserved_from_base() {
        let result = parseTimeString("9:30 AM", relativeTo: baseDate)
        guard let r = result else { return #expect(Bool(false), "parse returned nil") }
        let comps = Calendar.current.dateComponents([.day], from: r)
        #expect(comps.day == 4)
    }
}

@Suite("parseTimeString — invalid input")
struct TimeParsingInvalidInputTests {

    @Test func empty_string_returns_nil() {
        #expect(parseTimeString("", relativeTo: baseDate) == nil)
    }

    @Test func whitespace_only_returns_nil() {
        #expect(parseTimeString("   ", relativeTo: baseDate) == nil)
    }

    @Test func gibberish_returns_nil() {
        #expect(parseTimeString("not a time", relativeTo: baseDate) == nil)
    }

    @Test func letters_only_returns_nil() {
        #expect(parseTimeString("abc", relativeTo: baseDate) == nil)
    }

    @Test func partial_colon_returns_nil() {
        #expect(parseTimeString("9:", relativeTo: baseDate) == nil)
    }
}
