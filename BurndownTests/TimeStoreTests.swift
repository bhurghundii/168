import SwiftData
import XCTest
@testable import Burndown

@MainActor
final class TimeStoreTests: XCTestCase {
    // Disambiguates from `objc_category *Category`, which `ObjectiveC`
    // (pulled in transitively by XCTest) also declares at global scope.
    private typealias Category = Burndown.Category

    // Fixed calendar + a fixed "now" (Wed June 3, 2026, noon — mid-week, no
    // boundary anywhere nearby) so every test is fully deterministic.
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

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Category.self, Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeStore(container: ModelContainer, now: @escaping () -> Date, liveActivityManager: LiveActivityManaging? = nil) -> TimeStore {
        TimeStore(modelContext: container.mainContext, calendar: calendar, now: now, liveActivityManager: liveActivityManager ?? FakeLiveActivityManager())
    }

    func testStartCreatesRunningSession() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        let session = try store.start(category: category)

        XCTAssertNil(session.endedAt)
        XCTAssertNotNil(store.runningSession(for: category))
    }

    func testStartingSecondCategoryStopsFirstRunningSession() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let a = Category(name: "A", weeklyHours: 10, sortOrder: 0)
        let b = Category(name: "B", weeklyHours: 10, sortOrder: 1)
        container.mainContext.insert(a)
        container.mainContext.insert(b)

        let sessionA = try store.start(category: a)
        try store.start(category: b)

        XCTAssertNotNil(sessionA.endedAt)
        XCTAssertNil(store.runningSession(for: a))
        XCTAssertNotNil(store.runningSession(for: b))
    }

    func testStopEndsRunningSession() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.start(category: category)
        try store.stop(category: category)

        XCTAssertNil(store.runningSession(for: category))
    }

    func testStopIsIdempotentDoubleStopDoesNotDuplicate() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.start(category: category)
        try store.stop(category: category)
        try store.stop(category: category) // must be a silent no-op, not a second entry

        XCTAssertEqual(category.sessions.count, 1)
    }

    func testStopWithNoRunningSessionIsNoOp() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        XCTAssertNoThrow(try store.stop(category: category))
        XCTAssertEqual(category.sessions.count, 0)
    }

    func testRelaunchMidSessionResumesWithCorrectElapsed() throws {
        let container = try makeContainer()
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        let startTime = date(2026, 6, 3, 9)
        let firstStore = makeStore(container: container) { startTime }
        try firstStore.start(category: category)

        // Simulate relaunch: a brand-new TimeStore against the *same*
        // persistent container, with "now" advanced by 90 minutes. Elapsed
        // must derive purely from the persisted startedAt, never from
        // anything the first store instance held in memory.
        let laterTime = startTime.addingTimeInterval(90 * 60)
        let secondStore = makeStore(container: container) { laterTime }

        guard let running = secondStore.runningSession(for: category) else {
            XCTFail("Expected the session to still be running after relaunch")
            return
        }
        let elapsed = secondStore.now().timeIntervalSince(running.startedAt)
        XCTAssertEqual(elapsed, 90 * 60, accuracy: 1)
    }

    func testAdjustPositiveIncreasesSpent() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.adjust(category: category, byHours: 1)

        XCTAssertEqual(store.spent(category, in: store.currentWeekInterval()), 3600, accuracy: 1)
    }

    func testAdjustNegativeDecreasesSpent() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.adjust(category: category, byHours: 2)
        try store.adjust(category: category, byHours: -0.5)

        XCTAssertEqual(store.spent(category, in: store.currentWeekInterval()), 1.5 * 3600, accuracy: 1)
    }

    func testAdjustZeroHoursIsNoOp() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let store = makeStore(container: container) { fixedNow }
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.adjust(category: category, byHours: 0)

        XCTAssertEqual(category.sessions.count, 0)
    }

    // MARK: - Live Activity wiring

    func testStartCallsLiveActivityManagerWithCategoryStartedAtAndDeadline() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.start(category: category)

        XCTAssertEqual(fake.startCalls.count, 1)
        let call = try XCTUnwrap(fake.startCalls.first)
        XCTAssertEqual(call.categoryId, category.id)
        XCTAssertEqual(call.categoryName, "Work")
        XCTAssertEqual(call.startedAt, fixedNow)
        // 10 hours budgeted, nothing spent yet -> deadline is 10h after start.
        XCTAssertEqual(call.budgetDeadline?.timeIntervalSince(fixedNow) ?? 0, 10 * 3600, accuracy: 1)
    }

    func testStartWhenAlreadyOverBudgetPassesNilDeadline() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 1, sortOrder: 0)
        container.mainContext.insert(category)
        try store.adjust(category: category, byHours: 2) // already 1h over the 1h budget

        try store.start(category: category)

        XCTAssertEqual(fake.startCalls.last?.budgetDeadline, nil)
    }

    func testStartingSecondCategoryEndsFirstCategoryLiveActivity() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let a = Category(name: "A", weeklyHours: 10, sortOrder: 0)
        let b = Category(name: "B", weeklyHours: 10, sortOrder: 1)
        container.mainContext.insert(a)
        container.mainContext.insert(b)

        try store.start(category: a)
        try store.start(category: b)

        XCTAssertTrue(fake.endedCategoryIds.contains(a.id))
        XCTAssertEqual(fake.startCalls.map(\.categoryId), [a.id, b.id])
    }

    func testStopEndsLiveActivityForCategory() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.start(category: category)
        try store.stop(category: category)

        XCTAssertTrue(fake.endedCategoryIds.contains(category.id))
    }

    func testStopWithNoRunningSessionDoesNotCallLiveActivityManager() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.stop(category: category)

        XCTAssertTrue(fake.endedCategoryIds.isEmpty)
    }

    func testSetWeeklyHoursWhileRunningUpdatesLiveActivityDeadline() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)
        try store.start(category: category)

        try store.setWeeklyHours(category, hours: 5)

        XCTAssertEqual(fake.updateCalls.count, 1)
        XCTAssertEqual(fake.updateCalls.first?.categoryId, category.id)
        XCTAssertEqual(fake.updateCalls.first?.budgetDeadline?.timeIntervalSince(fixedNow) ?? 0, 5 * 3600, accuracy: 1)
    }

    func testSetWeeklyHoursWhileNotRunningDoesNotTouchLiveActivity() throws {
        let container = try makeContainer()
        let fixedNow = date(2026, 6, 3, 12)
        let fake = FakeLiveActivityManager()
        let store = makeStore(container: container, now: { fixedNow }, liveActivityManager: fake)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)

        try store.setWeeklyHours(category, hours: 5)

        XCTAssertTrue(fake.updateCalls.isEmpty)
    }

    // MARK: - Total allocated hours

    func testTotalAllocatedHoursSumsAllCategories() throws {
        let container = try makeContainer()
        let store = makeStore(container: container) { self.date(2026, 6, 3, 12) }
        let a = Category(name: "A", weeklyHours: 10, sortOrder: 0)
        let b = Category(name: "B", weeklyHours: 20.5, sortOrder: 1)
        container.mainContext.insert(a)
        container.mainContext.insert(b)

        XCTAssertEqual(store.totalAllocatedHours([a, b]), 30.5, accuracy: 0.001)
    }

    func testTotalAllocatedHoursIsZeroWithNoCategories() throws {
        let container = try makeContainer()
        let store = makeStore(container: container) { self.date(2026, 6, 3, 12) }

        XCTAssertEqual(store.totalAllocatedHours([]), 0)
    }
}
