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

// MARK: - specificDate dedup key

@Suite("CalendarImportService — dedupKey(name:specificDate:)")
struct SpecificDateDedupKeyTests {

    @Test func sameDaySameNameProducesSameKey() {
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let evening = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        let k1 = CalendarImportService.dedupKey(name: "Dentist", specificDate: morning)
        let k2 = CalendarImportService.dedupKey(name: "Dentist", specificDate: evening)
        #expect(k1 == k2, "Same calendar day should dedupe regardless of exact time")
    }

    @Test func differentDaysProduceDifferentKeys() {
        let today = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        let k1 = CalendarImportService.dedupKey(name: "Dentist", specificDate: today)
        let k2 = CalendarImportService.dedupKey(name: "Dentist", specificDate: nextWeek)
        #expect(k1 != k2)
    }
}

// MARK: - classify(_:existingEvents:)

@Suite("CalendarImportService — classify")
struct ClassifyTests {

    private func makeOccurrence(
        title: String, day: DayOfWeek, date: Date, isRecurring: Bool
    ) -> CalendarImportService.RawOccurrence {
        CalendarImportService.RawOccurrence(
            id: UUID().uuidString, title: title, day: day,
            startTime: date, endTime: date.addingTimeInterval(3600),
            calendarTitle: "Test", isRecurring: isRecurring
        )
    }

    private func weekday(_ weekday: Int, weeksFromNow: Int = 0) -> Date {
        var comps = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekOfYear = (comps.weekOfYear ?? 0) + weeksFromNow
        comps.weekday = weekday
        comps.hour = 9
        return Calendar.current.date(from: comps) ?? Date()
    }

    @Test func recurringOccurrencesAcrossMultipleWeeksCollapseToOneCandidate() {
        // Same title/day/time-of-day fetched 4 weeks in a row — EventKit's expansion
        // of a recurring event across a multi-week fetch.
        let occurrences = (0..<4).map {
            makeOccurrence(title: "Math Class", day: .monday, date: weekday(2, weeksFromNow: $0), isRecurring: true)
        }
        let result = CalendarImportService.classify(occurrences, existingEvents: [])
        #expect(result.count == 1)
        #expect(result.first?.isRecurring == true)
    }

    @Test func oneOffOccurrencesStaySeparate() {
        let occurrences = [
            makeOccurrence(title: "Dentist", day: .tuesday, date: weekday(3, weeksFromNow: 0), isRecurring: false),
            makeOccurrence(title: "Dentist", day: .tuesday, date: weekday(3, weeksFromNow: 2), isRecurring: false)
        ]
        let result = CalendarImportService.classify(occurrences, existingEvents: [])
        #expect(result.count == 2)
        #expect(result.allSatisfy { !$0.isRecurring })
    }

    @Test func mixedRecurringAndOneOffClassifyCorrectly() {
        let recurring = (0..<3).map {
            makeOccurrence(title: "Soccer", day: .thursday, date: weekday(5, weeksFromNow: $0), isRecurring: true)
        }
        let oneOff = makeOccurrence(title: "Orthodontist", day: .friday, date: weekday(6, weeksFromNow: 1), isRecurring: false)
        let result = CalendarImportService.classify(recurring + [oneOff], existingEvents: [])
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "Soccer" && $0.isRecurring })
        #expect(result.contains { $0.title == "Orthodontist" && !$0.isRecurring })
    }

    @Test func dedupesAgainstExistingRecurringEvent() {
        let existing = Event(name: "Math Class", isFixed: true, fixedDay: .monday, startTime: weekday(2))
        let occurrences = [makeOccurrence(title: "Math Class", day: .monday, date: weekday(2), isRecurring: true)]
        let result = CalendarImportService.classify(occurrences, existingEvents: [existing])
        #expect(result.isEmpty)
    }

    @Test func dedupesAgainstExistingOneOffEventOnSameDate() {
        let date = weekday(3)
        let existing = Event(name: "Dentist", isFixed: true, fixedDay: .tuesday, startTime: date, specificDate: date)
        let occurrences = [makeOccurrence(title: "Dentist", day: .tuesday, date: date, isRecurring: false)]
        let result = CalendarImportService.classify(occurrences, existingEvents: [existing])
        #expect(result.isEmpty)
    }

    @Test func oneOffDoesNotDedupeAgainstUnrelatedRecurringEventSameWeekday() {
        // A recurring "Dentist" checkup on Tuesdays shouldn't block importing a
        // genuinely separate one-time "Dentist" appointment that happens to also fall on a Tuesday.
        let existing = Event(name: "Dentist", isFixed: true, fixedDay: .tuesday)
        let occurrences = [makeOccurrence(title: "Dentist", day: .tuesday, date: weekday(3, weeksFromNow: 2), isRecurring: false)]
        let result = CalendarImportService.classify(occurrences, existingEvents: [existing])
        #expect(result.count == 1)
    }
}
