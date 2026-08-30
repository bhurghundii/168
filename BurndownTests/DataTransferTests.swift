import SwiftData
import XCTest
@testable import Burndown

@MainActor
final class DataTransferTests: XCTestCase {
    // Disambiguates from `objc_category *Category`, which `ObjectiveC`
    // (pulled in transitively by XCTest) also declares at global scope.
    private typealias Category = Burndown.Category

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Category.self, Session.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func encode(_ payload: ExportPayloadV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func testExportProducesValidVersion1JSON() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)
        try store.adjust(category: category, byHours: 1)

        let data = try store.exportJSON()
        let payload = try DataTransfer.decode(data)

        XCTAssertEqual(payload.version, ExportPayloadV1.currentVersion)
        XCTAssertEqual(payload.categories.count, 1)
        XCTAssertEqual(payload.sessions.count, 1)
    }

    func testImportReplacesAllExistingDataDestructively() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let oldCategory = Category(name: "Old", weeklyHours: 5, sortOrder: 0)
        container.mainContext.insert(oldCategory)
        try store.adjust(category: oldCategory, byHours: 1)

        let payload = ExportPayloadV1(
            categories: [CategoryDTO(id: UUID(), name: "New", weeklyHours: 8, sortOrder: 0)],
            sessions: []
        )
        try store.importJSON(encode(payload))

        let categories = try container.mainContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(categories.map(\.name), ["New"])
        let sessions = try container.mainContext.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(sessions.isEmpty)
    }

    func testExportThenImportRoundTripPreservesData() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let category = Category(name: "Work", weeklyHours: 10, sortOrder: 0)
        container.mainContext.insert(category)
        try store.adjust(category: category, byHours: 2)  // positive adjustment
        try store.adjust(category: category, byHours: -0.5) // negative adjustment

        let data = try store.exportJSON()
        try store.importJSON(data)

        let categories = try container.mainContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Work")

        let sessions = try container.mainContext.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 2)
        let directions = Set(sessions.map { ($0.endedAt ?? $0.startedAt) > $0.startedAt })
        XCTAssertEqual(directions, [true, false], "both the positive and negative adjustment's sign must survive the round trip")
    }

    func testImportRejectsUnknownVersionWithoutTouchingExistingData() throws {
        let container = try makeContainer()
        let store = TimeStore(modelContext: container.mainContext)
        let category = Category(name: "Existing", weeklyHours: 5, sortOrder: 0)
        container.mainContext.insert(category)

        var payload = ExportPayloadV1(categories: [], sessions: [])
        payload.version = 999

        XCTAssertThrowsError(try store.importJSON(try encode(payload))) { error in
            XCTAssertEqual(error as? DataTransferError, .unsupportedVersion(999))
        }

        let categories = try container.mainContext.fetch(FetchDescriptor<Category>())
        XCTAssertEqual(categories.map(\.name), ["Existing"])
    }
}
