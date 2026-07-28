import XCTest
@testable import progressio

// MARK: - In-memory stores

private final class MemoryWeekPlanStore: WeekPlanStore {
    var weeks: [String: WeekPlan] = [:]
    private let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    func loadWeek(start: Date) -> WeekPlan? {
        weeks[formatter.string(from: start)]
    }

    func save(_ week: WeekPlan, start: Date) {
        weeks[formatter.string(from: start)] = week
    }

    func fileURL(for start: Date) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("week-\(formatter.string(from: start)).json")
    }
}

private final class MemoryActivityReflectionStore: ActivityReflectionStore {
    var items: [ActivityReflection] = []
    func load() -> [ActivityReflection] { items }
    func save(_ items: [ActivityReflection]) { self.items = items }
}

private final class MemoryWeeklyReflectionStore: WeeklyReflectionStore {
    var items: [WeeklyReflection] = []
    func load() -> [WeeklyReflection] { items }
    func save(_ items: [WeeklyReflection]) { self.items = items }
}

private final class MemoryPhysicalIssueStore: PhysicalIssueStore {
    var items: [PhysicalIssue] = []
    func load() -> [PhysicalIssue] { items }
    func save(_ items: [PhysicalIssue]) { self.items = items }
}

private final class MemoryActivityIssueReportStore: ActivityIssueReportStore {
    var items: [ActivityIssueReport] = []
    func load() -> [ActivityIssueReport] { items }
    func save(_ items: [ActivityIssueReport]) { self.items = items }
}

private final class MemoryWeeklyIssueReviewStore: WeeklyIssueReviewStore {
    var items: [WeeklyIssueReview] = []
    func load() -> [WeeklyIssueReview] { items }
    func save(_ items: [WeeklyIssueReview]) { self.items = items }
}

private final class MemoryUnattachedRunStore: UnattachedRunStore {
    var runs: [UnattachedRun] = []
    func loadRuns() -> [UnattachedRun] { runs }
    func save(_ runs: [UnattachedRun]) { self.runs = runs }
}

private final class MemoryWeeklyTemplateStore: WeeklyTemplateStore {
    var templates: [WeeklyTemplate] = []
    func loadTemplates() -> [WeeklyTemplate] { templates }
    func save(_ templates: [WeeklyTemplate]) { self.templates = templates }
}

private final class MemoryImportedHealthStore: ImportedHealthWorkoutReferenceStore {
    var refs: [ImportedHealthWorkoutReference] = []
    func loadReferences() -> [ImportedHealthWorkoutReference] { refs }
    func save(_ references: [ImportedHealthWorkoutReference]) { refs = references }
}

private final class MemoryPeriodizedBlockStore: PeriodizedBlockStore {
    var blocks: [PeriodizedBlockTemplate] = []
    func loadBlocks() -> [PeriodizedBlockTemplate] { blocks }
    func save(_ blocks: [PeriodizedBlockTemplate]) { self.blocks = blocks }
}

final class ReflectionLogicTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func makeViewModel(week: WeekPlan) -> WeekPlannerViewModel {
        let weekStore = MemoryWeekPlanStore()
        weekStore.save(week, start: week.startOfWeek)
        let vm = WeekPlannerViewModel(
            calendar: calendar,
            templates: [],
            weekStore: weekStore,
            unattachedStore: MemoryUnattachedRunStore(),
            weeklyTemplateStore: MemoryWeeklyTemplateStore(),
            importedHealthStore: MemoryImportedHealthStore(),
            periodizedBlockStore: MemoryPeriodizedBlockStore(),
            activityReflectionStore: MemoryActivityReflectionStore(),
            weeklyReflectionStore: MemoryWeeklyReflectionStore(),
            physicalIssueStore: MemoryPhysicalIssueStore(),
            activityIssueReportStore: MemoryActivityIssueReportStore(),
            weeklyIssueReviewStore: MemoryWeeklyIssueReviewStore()
        )
        // ViewModel init loads "today's" week; pin to the fixture under test.
        if let loaded = weekStore.loadWeek(start: week.startOfWeek) {
            vm.weekPlan = loaded
            vm.currentStartOfWeek = week.startOfWeek
        }
        return vm
    }

    private func mondayWeek(with workouts: [Workout]) -> WeekPlan {
        // Fixed Monday: 2024-01-01 was a Monday UTC.
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = 1
        let start = calendar.date(from: comps)!
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayPlan(date: date, workouts: offset == 0 ? workouts : [])
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    // MARK: - WeekKey

    func testWeekKeyFormatsMondayAsYYYYMMDD() {
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 1
        comps.day = 1
        let monday = calendar.date(from: comps)!
        XCTAssertEqual(WeekKey.string(for: monday, calendar: calendar), "2024-01-01")
    }

    // MARK: - Unresolved for week close

    func testUnresolvedIncludesPlannedAndImportedExcludesDoneSkippedSoftDeleted() {
        var planned = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Planned")
        planned.status = .planned

        var imported = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Imported")
        imported.status = .imported

        var completed = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Done")
        completed.status = .completed

        var partial = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Partial")
        partial.status = .partiallyCompleted

        var skipped = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Skipped")
        skipped.status = .skipped

        var deleted = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Deleted")
        deleted.status = .planned
        deleted = SyncMetadata.softDelete(deleted)

        let vm = makeViewModel(week: mondayWeek(with: [planned, imported, completed, partial, skipped, deleted]))
        let unresolved = vm.unresolvedWorkoutsForWeekClose()
        let titles = Set(unresolved.map(\.workout.title))
        XCTAssertEqual(titles, ["Planned", "Imported"])
    }

    // MARK: - One reflection per workout

    func testSaveActivityReflectionUpsertsSingleActiveReflection() {
        let workout = Workout.manual(activityType: .strength, plannedDate: Date(), title: "Push")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))

        let first = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .ok,
            sessionRPE: 5,
            performanceNotes: "First",
            overwriteExisting: true
        )
        XCTAssertNotNil(first)

        let second = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .great,
            sessionRPE: 8,
            performanceNotes: "Second",
            overwriteExisting: true
        )
        XCTAssertEqual(second?.id, first?.id)
        XCTAssertEqual(vm.activityReflections.filter { !$0.isDeleted && $0.workoutID == workout.id }.count, 1)
        XCTAssertEqual(vm.activityReflection(for: workout.id)?.feel, .great)
        XCTAssertEqual(vm.activityReflection(for: workout.id)?.sessionRPE, 8)
    }

    func testOverwriteKeepLeavesExistingReflection() {
        let workout = Workout.manual(activityType: .strength, plannedDate: Date(), title: "Pull")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))
        _ = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .poor,
            sessionRPE: 4,
            performanceNotes: "Keep me",
            overwriteExisting: true
        )
        let kept = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .great,
            sessionRPE: 9,
            performanceNotes: "Ignore",
            overwriteExisting: false
        )
        XCTAssertEqual(kept?.feel, .poor)
        XCTAssertEqual(kept?.performanceNotes, "Keep me")
    }

    // MARK: - Issue report replace / resolve

    func testReplaceActivityIssueReportSoftDeletesPriors() {
        let workout = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Run")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))
        let reflection = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .ok,
            sessionRPE: 5,
            performanceNotes: nil,
            overwriteExisting: true
        )!
        let issue = vm.createPhysicalIssue(area: .knee, side: .left, title: "Knee", notes: nil)

        _ = vm.saveActivityIssueReport(
            physicalIssueID: issue.id,
            workoutID: workout.id,
            activityReflectionID: reflection.id,
            painLevel: 3,
            timing: .during,
            trend: .stable
        )
        _ = vm.replaceActivityIssueReport(
            forWorkoutID: workout.id,
            physicalIssueID: issue.id,
            activityReflectionID: reflection.id,
            painLevel: 6,
            timing: .after,
            trend: .worsened
        )

        let active = vm.activityIssueReports.filter { !$0.isDeleted && $0.workoutID == workout.id }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.painLevel, 6)
        XCTAssertEqual(vm.activityIssueReports.filter { $0.workoutID == workout.id && $0.isDeleted }.count, 1)
    }

    func testWeeklyReviewResolvedStampsResolvedAtWithoutHardDelete() {
        let workout = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Run")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))
        let issue = vm.createPhysicalIssue(area: .ankle, side: .right, title: nil, notes: nil)
        XCTAssertEqual(issue.status, .active)
        XCTAssertNil(issue.resolvedAt)

        _ = vm.saveWeeklyReflection(
            weekRating: 7,
            fatigue: .normal,
            recovery: .good,
            sleepQuality: .good,
            motivation: .high,
            mood: .good,
            lifeStress: .low,
            whatWentWell: nil,
            nextWeekChanges: nil,
            issueReviews: [(issueID: issue.id, trend: .resolved)]
        )

        let updated = vm.physicalIssues.first { $0.id == issue.id }
        XCTAssertEqual(updated?.status, .resolved)
        XCTAssertNotNil(updated?.resolvedAt)
        XCTAssertFalse(updated?.isDeleted ?? true)
        XCTAssertEqual(vm.physicalIssues.filter { $0.id == issue.id }.count, 1)
    }

    func testSoftDeleteWorkoutSoftDeletesReflectionAndReports() {
        let workout = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Run")
        let week = mondayWeek(with: [workout])
        let dayID = week.days[0].id
        let vm = makeViewModel(week: week)
        let reflection = vm.saveActivityReflection(
            workoutID: workout.id,
            feel: .ok,
            sessionRPE: 5,
            performanceNotes: nil,
            overwriteExisting: true
        )!
        let issue = vm.createPhysicalIssue(area: .hip, side: .both, title: nil, notes: nil)
        _ = vm.saveActivityIssueReport(
            physicalIssueID: issue.id,
            workoutID: workout.id,
            activityReflectionID: reflection.id,
            painLevel: 2,
            timing: .before,
            trend: .improved
        )

        vm.removeWorkout(dayID: dayID, workoutID: workout.id)

        XCTAssertNil(vm.activityReflection(for: workout.id))
        XCTAssertTrue(vm.activityIssueReports.filter { !$0.isDeleted && $0.workoutID == workout.id }.isEmpty)
        XCTAssertFalse(vm.activityReflections.filter { $0.workoutID == workout.id }.isEmpty) // tombstone kept
    }

    // MARK: - Task 036 (reflections optional)

    func testToggleStatusCompletesImmediatelyReflectionOptional() {
        let workout = Workout.manual(activityType: .roadRun, plannedDate: Date(), title: "Run")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))
        XCTAssertTrue(vm.toggleStatus(workoutID: workout.id))
        let status = vm.weekPlan.days.flatMap(\.activeWorkouts).first { $0.id == workout.id }?.status
        XCTAssertEqual(status, .completed)
    }

    func testFinalizeSkipAllowsEmptyReasonWithoutFakeRPE() {
        let workout = Workout.manual(activityType: .strength, plannedDate: Date(), title: "Push")
        let vm = makeViewModel(week: mondayWeek(with: [workout]))
        let reflection = vm.finalizeSkip(workoutID: workout.id, reason: "", discomfort: nil)
        let updated = vm.weekPlan.days.flatMap(\.activeWorkouts).first { $0.id == workout.id }
        XCTAssertEqual(updated?.status, .skipped)
        XCTAssertNil(updated?.skipReason)
        XCTAssertNil(reflection)
    }

    func testSkipReflectionDecodesMissingKindAsStandardWithDefaults() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "workoutID": "00000000-0000-0000-0000-000000000011",
          "feel": 3,
          "sessionRPE": 5
        }
        """.data(using: .utf8)!
        let reflection = try JSONDecoder().decode(ActivityReflection.self, from: json)
        XCTAssertEqual(reflection.reflectionKind, .standard)
        XCTAssertEqual(reflection.feel, .ok)
        XCTAssertEqual(reflection.sessionRPE, 5)
    }
}
