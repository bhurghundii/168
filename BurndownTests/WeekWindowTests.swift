import XCTest
@testable import Burndown

final class WeekWindowTests: XCTestCase {
    // Fixed calendar/time zone so every test is deterministic regardless of
    // where or when it runs. America/New_York observes DST, which is what
    // the two DST tests below need.
    private let calendar: Calendar = {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(identifier: "America/New_York")!
        return WeekWindow.mondayStart(from: base)
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    func testMondayStartCalendarHasFirstWeekdayMonday() {
        XCTAssertEqual(calendar.firstWeekday, 2)
    }

    // Verified: 2026-06-01 is a Monday, so this week runs June 1 - June 7.
    func testContainingReturnsMondayToNextMondayForMidWeekDate() {
        let wednesday = date(2026, 6, 3, 12)
        let week = WeekWindow.containing(wednesday, calendar: calendar)
        XCTAssertEqual(week.start, date(2026, 6, 1, 0))
        XCTAssertEqual(week.end, date(2026, 6, 8, 0))
    }

    func testContainingIsStableAtExactMondayMidnight() {
        let mondayMidnight = date(2026, 6, 1, 0)
        let week = WeekWindow.containing(mondayMidnight, calendar: calendar)
        XCTAssertEqual(week.start, mondayMidnight)
    }

    func testWeeksAgoZeroEqualsCurrentWeek() {
        let now = date(2026, 6, 3, 12)
        XCTAssertEqual(
            WeekWindow.weeksAgo(0, from: now, calendar: calendar),
            WeekWindow.containing(now, calendar: calendar)
        )
    }

    func testWeeksAgoNReturnsCorrectPastWeek() {
        let now = date(2026, 6, 3, 12) // week of Mon June 1
        let twoWeeksAgo = WeekWindow.weeksAgo(2, from: now, calendar: calendar)
        XCTAssertEqual(twoWeeksAgo.start, date(2026, 5, 18, 0)) // Mon May 18
        XCTAssertEqual(twoWeeksAgo.end, date(2026, 5, 25, 0))
    }

    func testDaysLeftInWeekOnMonday() {
        XCTAssertEqual(WeekWindow.daysLeftInWeek(from: date(2026, 6, 1, 9), calendar: calendar), 7)
    }

    func testDaysLeftInWeekOnWednesday() {
        XCTAssertEqual(WeekWindow.daysLeftInWeek(from: date(2026, 6, 3, 9), calendar: calendar), 5)
    }

    func testDaysLeftInWeekOnSunday() {
        XCTAssertEqual(WeekWindow.daysLeftInWeek(from: date(2026, 6, 7, 9), calendar: calendar), 1)
    }

    // 2026-03-08 is the second Sunday of March: the spring-forward day
    // (23h) in America/New_York. Its week is Mon Mar 2 - Sun Mar 8.
    func testDSTSpringForward23HourDayDoesNotShiftWeekBoundary() {
        let sundayDuringDST = date(2026, 3, 8, 20)
        let week = WeekWindow.containing(sundayDuringDST, calendar: calendar)

        XCTAssertEqual(week.start, date(2026, 3, 2, 0))
        XCTAssertEqual(week.end, date(2026, 3, 9, 0))
        // Wall-clock boundaries are exactly 7 days apart, but only
        // 7*24 - 1 hours of *absolute* elapsed time, because the week
        // contains a 23-hour day -- proving this uses real calendar day
        // boundaries, never `date.addingTimeInterval(7*24*3600)`.
        XCTAssertEqual(week.duration, 7 * 24 * 3600 - 3600, accuracy: 1)
    }

    // 2026-11-01 is the first Sunday of November: the fall-back day (25h)
    // in America/New_York. Its week is Mon Oct 26 - Sun Nov 1.
    func testDSTFallBack25HourDayDoesNotShiftWeekBoundary() {
        let sundayDuringFallBack = date(2026, 11, 1, 20)
        let week = WeekWindow.containing(sundayDuringFallBack, calendar: calendar)

        XCTAssertEqual(week.start, date(2026, 10, 26, 0))
        XCTAssertEqual(week.end, date(2026, 11, 2, 0))
        XCTAssertEqual(week.duration, 7 * 24 * 3600 + 3600, accuracy: 1)
    }
}
