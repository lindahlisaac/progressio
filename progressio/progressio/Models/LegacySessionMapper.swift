import Foundation

/// Converts between legacy `PlannedSession` and `Workout` models.
/// Used at weekly-template boundaries and when importing legacy `sessions` JSON.
///
/// **Known lossy round-trips** (legacy has no equivalent; safe until Task 007+):
/// - `WorkoutStatus.partiallyCompleted` → `PlanStatus.completed` on reverse mapping
/// - `ActivityType.trailRun` / `.walk` → `SessionKind.run` → `.roadRun` on reverse mapping
/// - `RunType.longRun` ↔ `RunCategory` (no legacy category; dropped both directions)
/// - `WorkoutSource` is not stored on `PlannedSession` (re-inferred on forward mapping)
/// - `timePeriod` defaults to `.am` unless caller supplies it on forward mapping
/// - `createdAt` falls back to `updatedAt` or `Date()` when migrating legacy sessions
enum LegacySessionMapper {

    // MARK: - PlannedSession → Workout

    static func workout(
        from session: PlannedSession,
        plannedDate: Date,
        timePeriod: TimePeriod = .am
    ) -> Workout {
        let activityType = ActivityType(sessionKind: session.kind)
        let runType = enduranceRunType(from: session, activityType: activityType)

        var plannedValues = plannedValues(from: session.runDetail, activityType: activityType)
        var completedValues = completedValues(from: session.actualRun, activityType: activityType)

        if let strengthLog = session.strengthLog {
            completedValues.completedStrengthRoutineSnapshot = strengthRoutineSnapshot(from: strengthLog)
            if strengthLog.isCompleted, completedValues.completedAt == nil {
                completedValues.completedAt = strengthLog.updatedAt ?? session.updatedAt
            }
        }

        let linkedHealthKitUUID = session.actualRun?.hkWorkoutUUID
            ?? session.runDetail?.hkWorkoutUUID

        let source = inferSource(
            session: session,
            linkedHealthKitUUID: linkedHealthKitUUID
        )

        let status = WorkoutStatus(planStatus: session.status)
        let (notes, skipReason) = splitNotes(session.note, status: status)

        let metadata = RecordMetadata(
            schemaVersion: WorkoutSchema.currentVersion,
            createdAt: session.updatedAt ?? Date(),
            updatedAt: session.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil,
            etag: session.etag
        )

        return Workout(
            id: session.id,
            metadata: metadata,
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: session.title,
            activityType: activityType,
            runType: runType,
            plannedValues: plannedValues,
            completedValues: completedValues,
            status: status,
            source: source,
            linkedWorkoutTemplateId: nil,
            linkedWeeklyTemplateId: nil,
            linkedPeriodizedBlockId: nil,
            linkedHealthKitUUID: linkedHealthKitUUID,
            templateName: session.templateName,
            notes: notes,
            skipReason: skipReason
        )
    }

    // MARK: - Workout → PlannedSession

    static func plannedSession(from workout: Workout) -> PlannedSession {
        let kind = workout.activityType.sessionKind
        let status = workout.status.planStatus

        let note = combinedNote(notes: workout.notes, skipReason: workout.skipReason, status: workout.status)

        var runDetail: RunDetailData?
        var actualRun: RunDetailData?

        if workout.activityType == .strength {
            runDetail = nil
            actualRun = nil
        } else {
            runDetail = runDetailData(
                from: workout.plannedValues,
                title: workout.title,
                runType: workout.runType,
                hkWorkoutUUID: nil
            )
            actualRun = runDetailData(
                from: workout.completedValues,
                title: workout.title,
                runType: workout.runType,
                hkWorkoutUUID: workout.linkedHealthKitUUID
            )
            if actualRun?.isEmpty == true { actualRun = nil }
            if runDetail?.isEmpty == true { runDetail = nil }
        }

        var strengthLog: StrengthLogState?
        if workout.activityType == .strength,
           let snapshot = workout.completedValues.completedStrengthRoutineSnapshot {
            strengthLog = strengthLogState(from: snapshot, sessionID: workout.id, workout: workout)
        }

        return PlannedSession(
            id: workout.id,
            title: workout.title,
            kind: kind,
            status: status,
            note: note,
            templateName: workout.templateName,
            runDetail: runDetail,
            strengthLog: strengthLog,
            updatedAt: workout.metadata.updatedAt,
            etag: workout.metadata.etag
        ).withActualRun(actualRun)
    }

    // MARK: - Endurance detail mapping

    private static func plannedValues(from detail: RunDetailData?, activityType: ActivityType) -> PlannedValues {
        guard let detail, activityType != .strength else { return .empty }
        return PlannedValues(
            plannedDistance: emptyToNil(detail.distance),
            plannedDuration: emptyToNil(detail.duration),
            plannedElevationGain: detail.elevationGain.flatMap { emptyToNil($0) },
            plannedIntensityRPE: nil,
            plannedDescription: combinedDescription(title: detail.title, notes: detail.notes),
            plannedRoute: nil,
            plannedStrengthRoutineSnapshot: nil
        )
    }

    private static func completedValues(from detail: RunDetailData?, activityType: ActivityType) -> CompletedValues {
        guard let detail, activityType != .strength else { return .empty }
        return CompletedValues(
            completedDistance: emptyToNil(detail.distance),
            completedDuration: emptyToNil(detail.duration),
            completedElevationGain: detail.elevationGain.flatMap { emptyToNil($0) },
            completedIntensityRPE: nil,
            completedCalories: nil,
            completedHeartRateAverage: emptyToNil(detail.averageHR),
            completedHeartRateMax: nil,
            completedDescription: emptyToNil(detail.notes),
            completedStrengthRoutineSnapshot: nil,
            completedAt: detail.eventDate ?? detail.updatedAt
        )
    }

    private static func runDetailData(
        from planned: PlannedValues,
        title: String,
        runType: RunType?,
        hkWorkoutUUID: String?
    ) -> RunDetailData? {
        let distance = planned.plannedDistance ?? ""
        let duration = planned.plannedDuration ?? ""
        let elevation = planned.plannedElevationGain ?? ""
        let notes = planned.plannedDescription ?? ""
        if distance.isEmpty, duration.isEmpty, elevation.isEmpty, notes.isEmpty, runType == nil {
            return nil
        }
        return RunDetailData(
            title: title,
            notes: notes,
            distance: distance,
            duration: duration,
            averageHR: "",
            category: runType?.runCategory,
            hkWorkoutUUID: hkWorkoutUUID,
            elevationGain: elevation,
            eventDate: nil,
            updatedAt: nil,
            etag: nil
        )
    }

    private static func runDetailData(
        from completed: CompletedValues,
        title: String,
        runType: RunType?,
        hkWorkoutUUID: String?
    ) -> RunDetailData? {
        let distance = completed.completedDistance ?? ""
        let duration = completed.completedDuration ?? ""
        let elevation = completed.completedElevationGain ?? ""
        let notes = completed.completedDescription ?? ""
        let hr = completed.completedHeartRateAverage ?? ""
        if distance.isEmpty, duration.isEmpty, elevation.isEmpty, notes.isEmpty, hr.isEmpty, hkWorkoutUUID == nil {
            return nil
        }
        return RunDetailData(
            title: title,
            notes: notes,
            distance: distance,
            duration: duration,
            averageHR: hr,
            category: runType?.runCategory,
            hkWorkoutUUID: hkWorkoutUUID,
            elevationGain: elevation,
            eventDate: completed.completedAt,
            updatedAt: completed.completedAt,
            etag: nil
        )
    }

    // MARK: - Strength mapping

    private static func strengthRoutineSnapshot(from log: StrengthLogState) -> StrengthRoutineSnapshot {
        let exercises = log.exercises.enumerated().map { index, exercise in
            StrengthExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                orderIndex: index,
                targetSets: exercise.sets.enumerated().map { setIndex, set in
                    StrengthSetSnapshot(
                        id: set.id,
                        setNumber: setIndex + 1,
                        targetReps: Int(set.repHint.filter { $0.isNumber }) ?? nil,
                        targetWeight: parseDouble(from: set.weight),
                        repHint: emptyToNil(set.repHint),
                        actualReps: emptyToNil(set.reps),
                        actualWeight: emptyToNil(set.weight),
                        notes: nil
                    )
                },
                muscleGroup: nil,
                notes: nil,
                exerciseRPE: emptyToNil(exercise.rpe)
            )
        }
        return StrengthRoutineSnapshot(exercises: exercises, completionNotes: nil)
    }

    private static func strengthLogState(
        from snapshot: StrengthRoutineSnapshot,
        sessionID: UUID,
        workout: Workout
    ) -> StrengthLogState {
        let exercises = snapshot.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
            ExerciseLog(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.targetSets.map { set in
                    SetLog(
                        id: set.id,
                        weight: set.actualWeight ?? (set.targetWeight.map { String(Int($0)) } ?? ""),
                        reps: set.actualReps ?? "",
                        repHint: set.repHint ?? set.targetReps.map(String.init) ?? ""
                    )
                },
                rpe: exercise.exerciseRPE ?? ""
            )
        }
        let isCompleted = workout.status == .completed || workout.status == .partiallyCompleted
        return StrengthLogState(
            sessionID: sessionID,
            exercises: exercises,
            isCompleted: isCompleted,
            updatedAt: workout.completedValues.completedAt ?? workout.metadata.updatedAt,
            etag: workout.metadata.etag
        )
    }

    // MARK: - Helpers

    private static func enduranceRunType(from session: PlannedSession, activityType: ActivityType) -> RunType? {
        guard activityType == .roadRun || activityType == .trailRun else { return nil }
        if let category = session.runDetail?.category ?? session.actualRun?.category {
            return RunType(runCategory: category)
        }
        return nil
    }

    private static func inferSource(session: PlannedSession, linkedHealthKitUUID: String?) -> WorkoutSource {
        if session.templateName != nil {
            return .template
        }
        if linkedHealthKitUUID != nil || session.status == .unplanned {
            return .appleHealth
        }
        if let note = session.note?.lowercased(), note.contains("healthkit") || note.contains("imported") {
            return .appleHealth
        }
        return .manual
    }

    private static func splitNotes(_ note: String?, status: WorkoutStatus) -> (notes: String?, skipReason: String?) {
        guard let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, nil)
        }
        if status == .skipped {
            return (nil, note)
        }
        return (note, nil)
    }

    private static func combinedNote(notes: String?, skipReason: String?, status: WorkoutStatus) -> String? {
        if status == .skipped, let skipReason, !skipReason.isEmpty {
            return skipReason
        }
        return notes
    }

    private static func combinedDescription(title: String, notes: String) -> String? {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNotes.isEmpty { return nil }
        return trimmedNotes
    }

    private static func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private static func parseDouble(from string: String) -> Double? {
        let filtered = string.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty, let value = Double(filtered) else { return nil }
        return value
    }
}

// MARK: - Private helpers

private extension PlannedSession {
    func withActualRun(_ actualRun: RunDetailData?) -> PlannedSession {
        var copy = self
        copy.actualRun = actualRun
        return copy
    }
}

private extension RunDetailData {
    var isEmpty: Bool {
        distance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (elevationGain ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && averageHR.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hkWorkoutUUID == nil
    }
}