import XCTest
@testable import progressio

final class LegacySessionMapperTests: XCTestCase {
    private let plannedDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01
    private let updatedAt = Date(timeIntervalSince1970: 1_704_153_600) // 2024-01-02

    // MARK: - Round-trip fixtures

    func testPlannedRunRoundTripPreservesPlannedValues() {
        let sessionID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let session = PlannedSession(
            id: sessionID,
            title: "Easy Run",
            kind: .run,
            status: .planned,
            runDetail: RunDetailData(
                title: "Easy Run",
                notes: "Keep it easy",
                distance: "5.0",
                duration: "45:00",
                averageHR: "",
                category: .easy,
                elevationGain: "200",
                updatedAt: updatedAt
            ),
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate, timePeriod: .am)
        let roundTripped = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(roundTripped.id, session.id)
        XCTAssertEqual(roundTripped.title, session.title)
        XCTAssertEqual(roundTripped.kind, session.kind)
        XCTAssertEqual(roundTripped.status, session.status)
        XCTAssertEqual(roundTripped.runDetail?.distance, "5.0")
        XCTAssertEqual(roundTripped.runDetail?.duration, "45:00")
        XCTAssertEqual(roundTripped.runDetail?.elevationGain, "200")
        XCTAssertEqual(roundTripped.runDetail?.notes, "Keep it easy")
        XCTAssertEqual(roundTripped.runDetail?.category, .easy)
        XCTAssertNil(roundTripped.actualRun)
    }

    func testCompletedRunRoundTripKeepsPlannedAndCompletedSeparate() {
        let sessionID = UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!
        var session = PlannedSession(
            id: sessionID,
            title: "Tempo Run",
            kind: .run,
            status: .completed,
            runDetail: RunDetailData(
                title: "Tempo Run",
                notes: "",
                distance: "6.0",
                duration: "50:00",
                averageHR: "",
                category: .tempo
            ),
            updatedAt: updatedAt
        )
        session.actualRun = RunDetailData(
            title: "Tempo Run",
            notes: "Felt strong",
            distance: "6.2",
            duration: "48:30",
            averageHR: "155",
            category: .tempo,
            eventDate: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)
        let roundTripped = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(roundTripped.runDetail?.distance, "6.0")
        XCTAssertEqual(roundTripped.runDetail?.duration, "50:00")
        XCTAssertEqual(roundTripped.actualRun?.distance, "6.2")
        XCTAssertEqual(roundTripped.actualRun?.duration, "48:30")
        XCTAssertEqual(roundTripped.actualRun?.averageHR, "155")
        XCTAssertEqual(roundTripped.actualRun?.notes, "Felt strong")
        XCTAssertEqual(roundTripped.status, .completed)
        XCTAssertEqual(workout.plannedValues.plannedDistance, "6.0")
        XCTAssertEqual(workout.completedValues.completedDistance, "6.2")
    }

    func testSkippedSessionRoundTripPreservesSkipReason() {
        let session = PlannedSession(
            id: UUID(),
            title: "Long Run",
            kind: .run,
            status: .skipped,
            note: "Travel day",
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)
        let roundTripped = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(workout.status, .skipped)
        XCTAssertEqual(workout.skipReason, "Travel day")
        XCTAssertNil(workout.notes)
        XCTAssertEqual(roundTripped.status, .skipped)
        XCTAssertEqual(roundTripped.note, "Travel day")
    }

    func testHealthKitAttachedSessionMapsUUIDAndSource() {
        let hkUUID = "HK-UUID-1234-ABCD"
        var session = PlannedSession(
            id: UUID(),
            title: "Morning Run",
            kind: .run,
            status: .completed,
            runDetail: RunDetailData(
                title: "Morning Run",
                notes: "",
                distance: "4.0",
                duration: "40:00",
                averageHR: "",
                category: .easy
            ),
            updatedAt: updatedAt
        )
        session.actualRun = RunDetailData(
            title: "Morning Run",
            notes: "",
            distance: "4.1",
            duration: "39:00",
            averageHR: "148",
            category: .easy,
            hkWorkoutUUID: hkUUID
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)

        XCTAssertEqual(workout.linkedHealthKitUUID, hkUUID)
        XCTAssertEqual(workout.source, .appleHealth)
        XCTAssertEqual(
            LegacySessionMapper.plannedSession(from: workout).actualRun?.hkWorkoutUUID,
            hkUUID
        )
    }

    func testUnplannedSessionMapsToImportedStatus() {
        let session = PlannedSession(
            id: UUID(),
            title: "Imported Run",
            kind: .run,
            status: .unplanned,
            note: "Imported from HealthKit",
            runDetail: RunDetailData(
                title: "Imported Run",
                notes: "",
                distance: "3.0",
                duration: "30:00",
                averageHR: "140",
                category: .easy,
                hkWorkoutUUID: "HK-IMPORT-1"
            ),
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)

        XCTAssertEqual(workout.status, .imported)
        XCTAssertEqual(workout.source, .appleHealth)
        XCTAssertEqual(LegacySessionMapper.plannedSession(from: workout).status, .unplanned)
    }

    func testStrengthSessionWithEmbeddedLogRoundTrips() {
        let sessionID = UUID(uuidString: "C3D4E5F6-A7B8-9012-CDEF-123456789012")!
        let setID = UUID(uuidString: "D4E5F6A7-B8C9-0123-DEF0-234567890123")!
        let exerciseID = UUID(uuidString: "E5F6A7B8-C9D0-1234-EF01-345678901234")!

        var session = PlannedSession(
            id: sessionID,
            title: "Upper Push",
            kind: .strength,
            status: .completed,
            templateName: "Upper Push",
            updatedAt: updatedAt
        )
        session.strengthLog = StrengthLogState(
            sessionID: sessionID,
            exercises: [
                ExerciseLog(
                    id: exerciseID,
                    name: "Bench Press",
                    sets: [
                        SetLog(id: setID, weight: "135", reps: "8", repHint: "8")
                    ],
                    rpe: "7"
                )
            ],
            isCompleted: true,
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)
        let roundTripped = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(workout.activityType, .strength)
        XCTAssertEqual(workout.source, .template)
        XCTAssertEqual(workout.templateName, "Upper Push")
        XCTAssertEqual(
            workout.completedValues.completedStrengthRoutineSnapshot?.exercises.first?.name,
            "Bench Press"
        )
        XCTAssertEqual(roundTripped.kind, .strength)
        XCTAssertEqual(roundTripped.templateName, "Upper Push")
        XCTAssertEqual(roundTripped.strengthLog?.exercises.first?.name, "Bench Press")
        XCTAssertEqual(roundTripped.strengthLog?.exercises.first?.sets.first?.reps, "8")
        XCTAssertTrue(roundTripped.strengthLog?.isCompleted == true)
    }

    func testTemplateSessionMapsSourceAndTemplateName() {
        let session = PlannedSession(
            id: UUID(),
            title: "Leg Day",
            kind: .strength,
            status: .planned,
            templateName: "Leg Day",
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)

        XCTAssertEqual(workout.source, .template)
        XCTAssertEqual(workout.templateName, "Leg Day")
        XCTAssertEqual(LegacySessionMapper.plannedSession(from: workout).templateName, "Leg Day")
    }

    func testBikeSessionRoundTripMapsToCycle() {
        let session = PlannedSession(
            id: UUID(),
            title: "Recovery Ride",
            kind: .cycle,
            status: .planned,
            runDetail: RunDetailData(
                title: "Recovery Ride",
                notes: "",
                distance: "",
                duration: "60:00",
                averageHR: "",
                category: nil
            ),
            updatedAt: updatedAt
        )

        let workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)
        let roundTripped = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(workout.activityType, .bike)
        XCTAssertEqual(roundTripped.kind, .cycle)
        XCTAssertEqual(roundTripped.runDetail?.duration, "60:00")
    }

    // MARK: - Documented lossy conversions

    func testPartiallyCompletedStatusMapsToCompletedOnReverse() {
        let workout = Workout(
            id: UUID(),
            metadata: RecordMetadata(updatedAt: updatedAt),
            plannedDate: plannedDate,
            title: "Threshold Run",
            activityType: .roadRun,
            plannedValues: PlannedValues(plannedDistance: "8"),
            completedValues: CompletedValues(completedDistance: "5"),
            status: .partiallyCompleted,
            source: .manual
        )

        let session = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(session.status, .completed)
    }

    func testTrailRunActivityTypeLossyRoundTripDefaultsToRoadRun() {
        let workout = Workout(
            id: UUID(),
            metadata: RecordMetadata(updatedAt: updatedAt),
            plannedDate: plannedDate,
            title: "Trail Run",
            activityType: .trailRun,
            status: .planned,
            source: .manual
        )

        let session = LegacySessionMapper.plannedSession(from: workout)

        XCTAssertEqual(session.kind, .run)
        XCTAssertEqual(ActivityType(sessionKind: session.kind), .roadRun)
    }
}
