import XCTest
@testable import Burndown

final class BudgetHealthTests: XCTestCase {
    func testZeroHoursIsComfy() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 0), .comfy)
    }

    func testJustUnderComfyCeilingIsComfy() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 59.9), .comfy)
    }

    func testComfyCeilingBoundaryIsComfy() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 60), .comfy)
    }

    func testJustOverComfyCeilingIsTight() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 60.1), .tight)
    }

    func testJustUnderTightCeilingIsTight() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 79.9), .tight)
    }

    func testTightCeilingBoundaryIsTight() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 80), .tight)
    }

    func testJustOverTightCeilingIsCritical() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 80.1), .critical)
    }

    func testFullyAllocated168IsCritical() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 168), .critical)
    }

    func testOverAllocatedIsStillCriticalNotANewState() {
        XCTAssertEqual(BudgetHealth.level(forAllocatedHours: 250), .critical)
    }
}
