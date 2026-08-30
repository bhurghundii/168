import XCTest
@testable import Burndown

final class FormattingTests: XCTestCase {
    func testZeroSeconds() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 0), "0m")
    }

    func testUnderOneHour() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 25 * 60), "25m")
    }

    func testOverOneHour() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 90 * 60), "1h 30m")
    }

    // Minutes are always shown alongside hours, even at an exact hour, for
    // consistent scan-width everywhere the label appears.
    func testExactHourStillShowsMinutes() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 2 * 3600), "2h 0m")
    }

    func testNegativeUnderOneHour() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: -10 * 60), "-10m")
    }

    func testNegativeOverOneHour() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: -90 * 60), "-1h 30m")
    }

    func testRoundsToNearestMinuteBelowHalf() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 89), "1m") // 1.483 min -> 1m
    }

    func testRoundsToNearestMinuteAtOrAboveHalf() {
        XCTAssertEqual(Formatting.remainingLabel(seconds: 90), "2m") // 1.5 min -> 2m
    }

    // MARK: - liveLabel (second-precision, used for the running row)

    func testLiveLabelUnderOneMinute() {
        XCTAssertEqual(Formatting.liveLabel(seconds: 7), "0:07")
    }

    func testLiveLabelUnderOneHour() {
        XCTAssertEqual(Formatting.liveLabel(seconds: 65), "1:05")
    }

    func testLiveLabelOverOneHour() {
        XCTAssertEqual(Formatting.liveLabel(seconds: 3725), "1:02:05") // 1h 2m 5s
    }

    func testLiveLabelNegative() {
        XCTAssertEqual(Formatting.liveLabel(seconds: -65), "-1:05")
    }

    // This is the concrete regression test for "the time isn't realtime":
    // liveLabel must visibly change second over second while a session is
    // running, unlike remainingLabel which only moves once a minute.
    func testLiveLabelChangesEverySecondUnlikeRemainingLabel() {
        let t = 42.0
        let tPlusOneSecond = 43.0
        XCTAssertNotEqual(Formatting.liveLabel(seconds: t), Formatting.liveLabel(seconds: tPlusOneSecond))
        // Meanwhile remainingLabel is deliberately insensitive to whole seconds.
        XCTAssertEqual(Formatting.remainingLabel(seconds: t), Formatting.remainingLabel(seconds: tPlusOneSecond))
    }
}
