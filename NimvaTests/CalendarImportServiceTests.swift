import Testing
import Foundation
@testable import Nimva

@Suite("CalendarImportService — nimvaDay mapping")
struct NimvaDayMappingTests {

    // Calendar.component(.weekday) returns 1=Sun, 2=Mon … 7=Sat
    // DayOfWeek.rawValue:              1=Mon, 2=Tue … 7=Sun

    private func dateWithWeekday(_ weekday: Int) -> Date {
        var comps = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = weekday
        return Calendar.current.date(from: comps) ?? Date()
    }

    @Test func sunday_maps_to_sunday() {
        let date = dateWithWeekday(1)
        #expect(CalendarImportService.nimvaDay(from: date) == .sunday)
    }

    @Test func monday_maps_to_monday() {
        let date = dateWithWeekday(2)
        #expect(CalendarImportService.nimvaDay(from: date) == .monday)
    }

    @Test func tuesday_maps_to_tuesday() {
        let date = dateWithWeekday(3)
        #expect(CalendarImportService.nimvaDay(from: date) == .tuesday)
    }

    @Test func wednesday_maps_to_wednesday() {
        let date = dateWithWeekday(4)
        #expect(CalendarImportService.nimvaDay(from: date) == .wednesday)
    }

    @Test func thursday_maps_to_thursday() {
        let date = dateWithWeekday(5)
        #expect(CalendarImportService.nimvaDay(from: date) == .thursday)
    }

    @Test func friday_maps_to_friday() {
        let date = dateWithWeekday(6)
        #expect(CalendarImportService.nimvaDay(from: date) == .friday)
    }

    @Test func saturday_maps_to_saturday() {
        let date = dateWithWeekday(7)
        #expect(CalendarImportService.nimvaDay(from: date) == .saturday)
    }

    @Test func all_7_days_are_non_nil() {
        for weekday in 1...7 {
            let date = dateWithWeekday(weekday)
            #expect(CalendarImportService.nimvaDay(from: date) != nil, "weekday \(weekday) should map to a DayOfWeek")
        }
    }

    @Test func mapping_produces_all_7_distinct_values() {
        let results = (1...7).compactMap { CalendarImportService.nimvaDay(from: dateWithWeekday($0)) }
        let unique = Set(results)
        #expect(unique.count == 7)
    }
}

@Suite("CalendarImportService — dedupKey")
struct DedupKeyTests {

    @Test func basic_format_is_name_underscore_rawValue() {
        let key = CalendarImportService.dedupKey(name: "Math", day: .monday)
        #expect(key == "math_1")
    }

    @Test func name_is_lowercased() {
        let upper = CalendarImportService.dedupKey(name: "PHYSICS", day: .wednesday)
        let lower = CalendarImportService.dedupKey(name: "physics", day: .wednesday)
        #expect(upper == lower)
    }

    @Test func mixed_case_normalised() {
        let key = CalendarImportService.dedupKey(name: "Bio Lab", day: .friday)
        #expect(key == "bio lab_5")
    }

    @Test func different_days_produce_different_keys() {
        let k1 = CalendarImportService.dedupKey(name: "Gym", day: .monday)
        let k2 = CalendarImportService.dedupKey(name: "Gym", day: .tuesday)
        #expect(k1 != k2)
    }

    @Test func different_names_same_day_produce_different_keys() {
        let k1 = CalendarImportService.dedupKey(name: "Gym", day: .monday)
        let k2 = CalendarImportService.dedupKey(name: "Run", day: .monday)
        #expect(k1 != k2)
    }

    @Test func sunday_rawValue_is_7() {
        let key = CalendarImportService.dedupKey(name: "rest", day: .sunday)
        #expect(key == "rest_7")
    }

    @Test func raw_values_in_keys_match_day_enum_rawValues() {
        for day in DayOfWeek.allCases {
            let key = CalendarImportService.dedupKey(name: "x", day: day)
            let suffix = "_\(day.rawValue)"
            #expect(key.hasSuffix(suffix), "\(day) should produce key ending in \(suffix), got \(key)")
        }
    }
}
