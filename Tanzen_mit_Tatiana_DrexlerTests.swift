import XCTest
@testable import Tanzen_mit_Tatiana_Drexler

final class TanzenMitTatianaDrexlerTests: XCTestCase {
    func testTrainingPlanTypeDisplayNameNotEmpty() {
        let all = TrainingPlanType.allCases
        XCTAssertFalse(all.isEmpty)
        for plan in all {
            XCTAssertFalse(plan.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testTrainingGoalDisplayNameNotEmpty() {
        let all = TrainingGoal.allCases
        XCTAssertFalse(all.isEmpty)
        for goal in all {
            XCTAssertFalse(goal.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
