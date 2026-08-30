import XCTest
@testable import Burndown

final class TimeMathTests: XCTestCase {
    private let calendar: Calendar = {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(identifier: "America/New_York")!
        return WeekWindow.mondayStart(from: base)
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func week(containing date: Date) -> DateInterval {
        WeekWindow.containing(date, calendar: calendar)
    }

    func testOverlapSessionFullyInsideWeek() {
        // Monday June 1, 2026, 9am - 11am: fully inside its own week.
        let start = date(2026, 6, 1, 9)
        let end = date(2026, 6, 1, 11)
        let session = Session(startedAt: start, endedAt: end)
        let overlap = TimeMath.overlap(of: session, with: week(containing: start), asOf: end)
        XCTAssertEqual(overlap, 2 * 3600, accuracy: 1)
    }

    func testOverlapSessionFullyOutsideWeek() {
        let start = date(2026, 6, 1, 9)
        let end = date(2026, 6, 1, 11)
        let session = Session(startedAt: start, endedAt: end)
        let unrelatedWeek = week(containing: date(2026, 6, 15, 9))
        XCTAssertEqual(TimeMath.overlap(of: session, with: unrelatedWeek, asOf: end), 0)
    }

    // The documented rule: a session crossing a week boundary has its
    // duration split proportionally between the two weeks it intersects.
    func testOverlapSessionCrossingSundayIntoMondaySplitsProportionally() {
        // Sunday June 7, 2026, 23:00 -> Monday June 8, 2026, 00:30.
        let start = date(2026, 6, 7, 23)
        let end = date(2026, 6, 8, 0, 30)
        let session = Session(startedAt: start, endedAt: end)

        let firstWeek = week(containing: start)  // Mon June 1 - Sun June 7
        let secondWeek = week(containing: end)   // Mon June 8 - Sun June 14

        let overlapFirst = TimeMath.overlap(of: session, with: firstWeek, asOf: end)
        let overlapSecond = TimeMath.overlap(of: session, with: secondWeek, asOf: end)

        XCTAssertEqual(overlapFirst, 3600, accuracy: 1)   // 23:00-24:00
        XCTAssertEqual(overlapSecond, 1800, accuracy: 1)  // 00:00-00:30
        XCTAssertEqual(overlapFirst + overlapSecond, end.timeIntervalSince(start), accuracy: 1)
    }

    func testOverlapRunningSessionUsesAsOfAsEffectiveEnd() {
        let start = date(2026, 6, 1, 9)
        let asOf = date(2026, 6, 1, 10, 30)
        let session = Session(startedAt: start, endedAt: nil)
        let overlap = TimeMath.overlap(of: session, with: week(containing: start), asOf: asOf)
        XCTAssertEqual(overlap, 90 * 60, accuracy: 1)
    }

    func testOverlapPositiveManualAdjustmentIsPositive() {
        let start = date(2026, 6, 1, 9)
        let end = date(2026, 6, 1, 10) // +1h
        let session = Session(startedAt: start, endedAt: end, manualAdjustment: true)
        let overlap = TimeMath.overlap(of: session, with: week(containing: start), asOf: end)
        XCTAssertEqual(overlap, 3600, accuracy: 1)
    }

    func testOverlapNegativeManualAdjustmentIsNegative() {
        let anchor = date(2026, 6, 1, 9)
        let end = date(2026, 6, 1, 8) // -1h: endedAt precedes startedAt
        let session = Session(startedAt: anchor, endedAt: end, manualAdjustment: true)
        let overlap = TimeMath.overlap(of: session, with: week(containing: anchor), asOf: anchor)
        XCTAssertEqual(overlap, -3600, accuracy: 1)
    }

    func testOverlapZeroDurationSessionReturnsZero() {
        let moment = date(2026, 6, 1, 9)
        let session = Session(startedAt: moment, endedAt: moment, manualAdjustment: true)
        XCTAssertEqual(TimeMath.overlap(of: session, with: week(containing: moment), asOf: moment), 0)
    }

    // Saturday 20:00 -> Sunday 22:00 spanning the spring-forward transition.
    // Wall clock reads 26 hours apart; real elapsed time is 25 hours because
    // of the missing 2am-3am hour. overlap() must report the real 25 hours.
    func testOverlapAcrossDSTBoundarySumsToRealElapsedSeconds() {
        let start = date(2026, 3, 7, 20)
        let end = date(2026, 3, 8, 22)
        let session = Session(startedAt: start, endedAt: end)
        let overlap = TimeMath.overlap(of: session, with: week(containing: start), asOf: end)
        XCTAssertEqual(overlap, end.timeIntervalSince(start), accuracy: 1)
        XCTAssertEqual(overlap, 25 * 3600, accuracy: 1)
    }
}
