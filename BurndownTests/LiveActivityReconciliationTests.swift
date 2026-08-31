import SwiftData
import XCTest
@testable import Burndown

@MainActor
final class LiveActivityReconciliationTests: XCTestCase {
    // Disambiguates from `objc_category *Category`, which `ObjectiveC`
    // (pulled in transitively by XCTest) also declares at global scope.
    private typealias Category = Burndown.Category

    private let fixedNow = Date(timeIntervalSince1970: 1_780_000_000)

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Category.self, Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeStore(container: ModelContainer, liveActivityManager: LiveActivityManaging) -> TimeStore {
        TimeStore(modelContext: container.mainContext, now: { self.fixedNow }, liveActivityManager: liveActivityManager)
    }

    // Mirrors DataTransferTests' local encode helper — DataTransfer only
    // exposes encode(categories:sessions:) (model objects), not a DTO/payload
    // overload, so a payload built directly from DTOs is encoded by hand.
    private func encode(_ payload: ExportPayloadV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    /// A category + a `Session(endedAt: nil)` inserted directly via the
    /// `modelContext`, bypassing `store.start(category:)` entirely — this is
    /// what a session restored by `importJSON` or a session whose Live
    /// Activity was killed by iOS's staleness limit looks like: genuinely
    /// running, but with nothing having ever called `LiveActivityManaging.start`.
    @discardableResult
    private func insertRunningSession(in container: ModelContainer, startedAt: Date, weeklyHours: Double = 10) -> Category {
        let category = Category(name: "Work", weeklyHours: weeklyHours, sortOrder: 0)
        container.mainContext.insert(category)
        let session = Session(startedAt: startedAt, category: category)
        container.mainContext.insert(session)
        return category
    }

    func testReconcileStartsActivityForRunningSessionMissingOne() throws {
        let container = try makeContainer()
        let staleStartedAt = fixedNow.addingTimeInterval(-3600)
        let category = insertRunningSession(in: container, startedAt: staleStartedAt)
        let fake = FakeLiveActivityManager()
        fake.stubbedActiveCategoryIds = [] // nothing active, as if the OS killed it
        let store = makeStore(container: container, liveActivityManager: fake)

        store.reconcileLiveActivities()

        XCTAssertEqual(fake.startCalls.count, 1)
        let call = try XCTUnwrap(fake.startCalls.first)
        XCTAssertEqual(call.categoryId, category.id)
        // Must resume from the session's TRUE persisted startedAt, not now(),
        // so elapsed time on the lock screen is correct after resurrection.
        XCTAssertEqual(call.startedAt, staleStartedAt)
        XCTAssertTrue(fake.endedCategoryIds.isEmpty)
    }

    func testReconcileEndsActivityWithNoMatchingRunningSession() throws {
        let container = try makeContainer()
        let staleId = UUID()
        let fake = FakeLiveActivityManager()
        fake.stubbedActiveCategoryIds = [staleId]
        let store = makeStore(container: container, liveActivityManager: fake)

        store.reconcileLiveActivities()

        XCTAssertEqual(fake.endedCategoryIds, [staleId])
        XCTAssertTrue(fake.startCalls.isEmpty)
    }

    func testReconcileEndsStrayActivitiesButKeepsTheMatchingOne() throws {
        let container = try makeContainer()
        let category = insertRunningSession(in: container, startedAt: fixedNow)
        let strayId = UUID()
        let fake = FakeLiveActivityManager()
        fake.stubbedActiveCategoryIds = [category.id, strayId]
        let store = makeStore(container: container, liveActivityManager: fake)

        store.reconcileLiveActivities()

        XCTAssertEqual(fake.endedCategoryIds, [strayId])
        XCTAssertTrue(fake.startCalls.isEmpty) // already active -> not redundantly restarted
    }

    func testReconcileIsNoOpWhenAlreadyConsistent() throws {
        let container = try makeContainer()
        let category = insertRunningSession(in: container, startedAt: fixedNow)
        let fake = FakeLiveActivityManager()
        fake.stubbedActiveCategoryIds = [category.id]
        let store = makeStore(container: container, liveActivityManager: fake)

        store.reconcileLiveActivities()

        XCTAssertTrue(fake.startCalls.isEmpty)
        XCTAssertTrue(fake.endedCategoryIds.isEmpty)
    }

    func testImportJSONReconcilesLiveActivities() throws {
        let container = try makeContainer()
        let staleId = UUID()
        let fake = FakeLiveActivityManager()
        fake.stubbedActiveCategoryIds = [staleId] // pre-import: an activity for a category the import will remove
        let store = makeStore(container: container, liveActivityManager: fake)

        let restoredCategoryId = UUID()
        let restoredSessionStartedAt = fixedNow.addingTimeInterval(-1800)
        let payload = ExportPayloadV1(
            categories: [CategoryDTO(id: restoredCategoryId, name: "Restored", weeklyHours: 8, sortOrder: 0)],
            sessions: [SessionDTO(id: UUID(), categoryId: restoredCategoryId, startedAt: restoredSessionStartedAt, endedAt: nil, manualAdjustment: false)]
        )

        try store.importJSON(try encode(payload))

        XCTAssertEqual(fake.endedCategoryIds, [staleId])
        XCTAssertEqual(fake.startCalls.last?.categoryId, restoredCategoryId)
        XCTAssertEqual(fake.startCalls.last?.startedAt, restoredSessionStartedAt)
    }
}
