import Foundation
@testable import Burndown

/// Records every call `TimeStore` makes into `LiveActivityManaging`, and
/// lets a test stub what the (fake) system currently reports as active —
/// without ever touching real ActivityKit, so `BurndownTests` stays
/// hermetic and deterministic.
final class FakeLiveActivityManager: LiveActivityManaging {
    struct StartCall: Equatable {
        var categoryId: UUID
        var categoryName: String
        var startedAt: Date
        var budgetDeadline: Date?
    }

    struct UpdateCall: Equatable {
        var categoryId: UUID
        var budgetDeadline: Date?
    }

    private(set) var startCalls: [StartCall] = []
    private(set) var endedCategoryIds: [UUID] = []
    private(set) var updateCalls: [UpdateCall] = []
    var stubbedActiveCategoryIds: Set<UUID> = []

    func start(categoryId: UUID, categoryName: String, startedAt: Date, budgetDeadline: Date?) {
        startCalls.append(StartCall(categoryId: categoryId, categoryName: categoryName, startedAt: startedAt, budgetDeadline: budgetDeadline))
        stubbedActiveCategoryIds.insert(categoryId)
    }

    func end(categoryId: UUID) {
        endedCategoryIds.append(categoryId)
        stubbedActiveCategoryIds.remove(categoryId)
    }

    func updateBudgetDeadline(categoryId: UUID, budgetDeadline: Date?) {
        updateCalls.append(UpdateCall(categoryId: categoryId, budgetDeadline: budgetDeadline))
    }

    func activeCategoryIds() -> Set<UUID> {
        stubbedActiveCategoryIds
    }
}
