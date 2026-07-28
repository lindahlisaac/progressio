import XCTest
@testable import progressio

final class WeekTotalsTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func week(with workoutsByOffset: [Int: [Workout]]) -> WeekPlan {
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayPlan(date: date, workouts: workoutsByOffset[offset] ?? [])
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    func testEmptyWeekHasNoTotals() {
        let plan = week(with: [:])
        XCTAssertTrue(WeekTotals.modalityTotals(for: plan).isEmpty)
    }

    func testOnlyPresentModalitiesAppear() {
        let plan = week(with: [
            0: [
                Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Easy", notes: nil)
            ]
        ])
        let totals = WeekTotals.modalityTotals(for: plan)
        XCTAssertEqual(totals.map(\.activityType), [.roadRun])
    }

    func testSkippedCountsTowardPlannedNotCompleted() {
        var run = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Run")
        run.plannedValues.plannedDistance = "5"
        run.status = .skipped

        let plan = week(with: [1: [run]])
        let totals = WeekTotals.modalityTotals(for: plan)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals[0].plannedAmount, 5, accuracy: 0.001)
        XCTAssertEqual(totals[0].completedAmount, 0, accuracy: 0.001)
        XCTAssertEqual(totals[0].unitLabel, "mi")
    }

    func testCompletedUsesActualDistanceWhenPresent() {
        var run = Workout.manual(activityType: .trailRun, plannedDate: Date(), title: "Trail")
        run.plannedValues.plannedDistance = "8"
        run.completedValues.completedDistance = "7.5"
        run.status = .completed

        let plan = week(with: [2: [run]])
        let total = WeekTotals.modalityTotals(for: plan)[0]
        XCTAssertEqual(total.completedAmount, 7.5, accuracy: 0.001)
        XCTAssertEqual(total.plannedAmount, 8, accuracy: 0.001)
    }

    func testSoftDeletedWorkoutsExcluded() {
        var run = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Gone")
        run.plannedValues.plannedDistance = "10"
        run = SyncMetadata.softDelete(run)

        let plan = week(with: [0: [run]])
        XCTAssertTrue(WeekTotals.modalityTotals(for: plan).isEmpty)
    }

    func testStrengthSessionCounts() {
        var done = Workout.manual(activityType: .strength, plannedDate: Date(), title: "Push")
        done.status = .completed
        let planned = Workout.manual(activityType: .strength, plannedDate: Date(), title: "Pull")

        let plan = week(with: [0: [done, planned]])
        let total = WeekTotals.modalityTotals(for: plan)[0]
        XCTAssertEqual(total.activityType, .strength)
        XCTAssertEqual(total.plannedAmount, 2, accuracy: 0.001)
        XCTAssertEqual(total.completedAmount, 1, accuracy: 0.001)
        XCTAssertEqual(total.unitLabel, "sessions")
    }

    func testBikeFallsBackToDurationWhenNoDistance() {
        var ride = Workout.manual(activityType: .bike, plannedDate: Date(), title: "Bike")
        ride.plannedValues.plannedDuration = "01:00:00"
        ride.status = .planned

        let plan = week(with: [3: [ride]])
        let total = WeekTotals.modalityTotals(for: plan)[0]
        XCTAssertEqual(total.unitLabel, "hr")
        XCTAssertEqual(total.plannedAmount, 1.0, accuracy: 0.001)
        XCTAssertEqual(total.completedAmount, 0, accuracy: 0.001)
    }

    func testStairMasterRollsUpByTimeWithElevationCaption() {
        var stairs = Workout.manual(activityType: .stairMaster, plannedDate: Date(), title: "Stairs")
        stairs.plannedValues.plannedDuration = "00:30:00"
        stairs.plannedValues.plannedElevationGain = "500"
        stairs.plannedValues.plannedLevel = "12"
        stairs.completedValues.completedDuration = "00:28:00"
        stairs.status = .completed

        let plan = week(with: [0: [stairs]])
        let total = WeekTotals.modalityTotals(for: plan)[0]
        XCTAssertEqual(total.activityType, .stairMaster)
        XCTAssertEqual(total.unitLabel, "hr")
        XCTAssertEqual(total.plannedAmount, 0.5, accuracy: 0.001)
        XCTAssertEqual(total.completedAmount, 28.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(total.plannedElevation, 500, accuracy: 0.001)
    }

    func testPrimaryMetricPreferenceOverridesWeekTotals() {
        var run = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Easy")
        run.plannedValues.plannedDistance = "5"
        run.plannedValues.plannedDuration = "01:00:00"
        run.status = .planned

        let defaults = UserDefaults(suiteName: "WeekTotalsTests.\(UUID().uuidString)")!
        let prefs = ActivityMetricPreferenceStore(defaults: defaults)
        prefs.setPrimaryMetric(.duration, for: .roadRun)

        let plan = week(with: [0: [run]])
        let total = WeekTotals.modalityTotals(for: plan, preferences: prefs)[0]
        XCTAssertEqual(total.unitLabel, "hr")
        XCTAssertEqual(total.plannedAmount, 1.0, accuracy: 0.001)
        XCTAssertEqual(total.primaryMetric, .duration)
    }

    func testDurationHoursParsing() {
        XCTAssertEqual(WeekTotals.durationHours(from: "01:30:00"), 1.5, accuracy: 0.001)
        XCTAssertEqual(WeekTotals.durationHours(from: "30:00"), 0.5, accuracy: 0.001)
        XCTAssertEqual(WeekTotals.miles(from: "6.2 mi"), 6.2, accuracy: 0.001)
    }
}
