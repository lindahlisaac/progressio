import Foundation

extension WeekPlannerViewModel {
    /// Active workouts that are not yet closed out for week completion.
    /// Closed = completed, partiallyCompleted, or skipped. Soft-deleted excluded.
    func unresolvedWorkoutsForWeekClose() -> [(day: DayPlan, workout: Workout)] {
        var unresolved: [(DayPlan, Workout)] = []
        for day in weekPlan.days {
            for workout in day.activeWorkouts {
                switch workout.status {
                case .completed, .partiallyCompleted, .skipped:
                    continue
                case .planned, .imported:
                    unresolved.append((day, workout))
                }
            }
        }
        return unresolved
    }

    func activityReflection(for workoutID: UUID) -> ActivityReflection? {
        activityReflections.first { !$0.isDeleted && $0.workoutID == workoutID }
    }

    func weeklyReflection(for weekKey: String) -> WeeklyReflection? {
        weeklyReflections.first { !$0.isDeleted && $0.weekKey == weekKey }
    }

    var currentWeekKey: String {
        WeekKey.string(for: currentStartOfWeek, calendar: calendar)
    }

    var activePhysicalIssues: [PhysicalIssue] {
        physicalIssues.filter { !$0.isDeleted && $0.status == .active }
    }

    func matchingActiveIssues(area: BodyArea, side: BodySide) -> [PhysicalIssue] {
        activePhysicalIssues.filter { $0.bodyArea == area && $0.side == side }
    }

    /// Reports for an issue, optionally limited to workouts in the current week.
    func reports(forIssue issueID: UUID, inCurrentWeekOnly: Bool = false) -> [ActivityIssueReport] {
        let allowedWorkoutIDs: Set<UUID>? = inCurrentWeekOnly
            ? Set(weekPlan.days.flatMap(\.activeWorkouts).map(\.id))
            : nil
        return activityIssueReports.filter { report in
            guard !report.isDeleted, report.physicalIssueID == issueID else { return false }
            if let allowed = allowedWorkoutIDs {
                return allowed.contains(report.workoutID)
            }
            return true
        }
    }

    func persistActivityReflections() { activityReflectionStore.save(activityReflections) }
    func persistWeeklyReflections() { weeklyReflectionStore.save(weeklyReflections) }
    func persistPhysicalIssues() { physicalIssueStore.save(physicalIssues) }
    func persistActivityIssueReports() { activityIssueReportStore.save(activityIssueReports) }
    func persistWeeklyIssueReviews() { weeklyIssueReviewStore.save(weeklyIssueReviews) }

    /// Saves or replaces the single reflection for a workout.
    @discardableResult
    func saveActivityReflection(
        workoutID: UUID,
        feel: SessionFeel,
        sessionRPE: Int,
        performanceNotes: String?,
        overwriteExisting: Bool
    ) -> ActivityReflection? {
        if let existing = activityReflection(for: workoutID), !overwriteExisting {
            return existing
        }

        let notes = performanceNotes.flatMap {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
        }

        if let idx = activityReflections.firstIndex(where: { !$0.isDeleted && $0.workoutID == workoutID }) {
            var updated = ActivityReflection(
                id: activityReflections[idx].id,
                workoutID: workoutID,
                feel: feel,
                sessionRPE: sessionRPE,
                performanceNotes: notes,
                schemaVersion: activityReflections[idx].schemaVersion,
                createdAt: activityReflections[idx].createdAt,
                updatedAt: activityReflections[idx].updatedAt,
                isDeleted: false,
                deletedAt: nil,
                etag: activityReflections[idx].etag
            )
            SyncMetadata.stampSave(&updated)
            activityReflections[idx] = updated
            persistActivityReflections()
            return updated
        }

        var created = ActivityReflection(
            workoutID: workoutID,
            feel: feel,
            sessionRPE: sessionRPE,
            performanceNotes: notes
        )
        SyncMetadata.stampNewRecord(&created)
        activityReflections.append(created)
        persistActivityReflections()
        return created
    }

    @discardableResult
    func createPhysicalIssue(
        area: BodyArea,
        side: BodySide,
        title: String?,
        notes: String?
    ) -> PhysicalIssue {
        var issue = PhysicalIssue(
            bodyArea: area,
            side: side,
            optionalTitle: title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 },
            optionalNotes: notes.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
        SyncMetadata.stampNewRecord(&issue)
        physicalIssues.append(issue)
        persistPhysicalIssues()
        return issue
    }

    @discardableResult
    func saveActivityIssueReport(
        physicalIssueID: UUID,
        workoutID: UUID,
        activityReflectionID: UUID,
        painLevel: Int,
        timing: DiscomfortTiming,
        trend: DiscomfortTrend
    ) -> ActivityIssueReport {
        var report = ActivityIssueReport(
            physicalIssueID: physicalIssueID,
            workoutID: workoutID,
            activityReflectionID: activityReflectionID,
            painLevel: painLevel,
            timing: timing,
            trendDuringActivity: trend
        )
        SyncMetadata.stampNewRecord(&report)
        activityIssueReports.append(report)
        persistActivityIssueReports()
        return report
    }

    /// Soft-deletes all active issue reports for a workout (used before overwrite / clear discomfort).
    func softDeleteActivityIssueReports(forWorkoutID workoutID: UUID) {
        var changed = false
        for index in activityIssueReports.indices {
            guard !activityIssueReports[index].isDeleted,
                  activityIssueReports[index].workoutID == workoutID
            else { continue }
            activityIssueReports[index] = SyncMetadata.softDelete(activityIssueReports[index])
            changed = true
        }
        if changed {
            persistActivityIssueReports()
        }
    }

    /// Soft-deletes the activity reflection and related issue reports for a workout.
    func softDeleteReflections(forWorkoutID workoutID: UUID) {
        var reflectionChanged = false
        for index in activityReflections.indices {
            guard !activityReflections[index].isDeleted,
                  activityReflections[index].workoutID == workoutID
            else { continue }
            activityReflections[index] = SyncMetadata.softDelete(activityReflections[index])
            reflectionChanged = true
        }
        if reflectionChanged {
            persistActivityReflections()
        }
        softDeleteActivityIssueReports(forWorkoutID: workoutID)
    }

    /// Replaces discomfort reports for a workout: soft-deletes priors, then optionally creates one new report.
    @discardableResult
    func replaceActivityIssueReport(
        forWorkoutID workoutID: UUID,
        physicalIssueID: UUID?,
        activityReflectionID: UUID,
        painLevel: Int,
        timing: DiscomfortTiming,
        trend: DiscomfortTrend
    ) -> ActivityIssueReport? {
        softDeleteActivityIssueReports(forWorkoutID: workoutID)
        guard let physicalIssueID else { return nil }
        return saveActivityIssueReport(
            physicalIssueID: physicalIssueID,
            workoutID: workoutID,
            activityReflectionID: activityReflectionID,
            painLevel: painLevel,
            timing: timing,
            trend: trend
        )
    }

    func skipAllUnresolvedForWeekClose(reason: String = "Auto-skipped on week close") {
        for item in unresolvedWorkoutsForWeekClose() {
            setWorkoutStatus(workoutID: item.workout.id, status: .skipped, note: reason)
        }
    }

    func markWeekComplete() {
        weekPlan.isWeekComplete = true
        weekPlan.weekCompletedAt = Date()
        SyncMetadata.stampSave(&weekPlan)
        persistWeek()
    }

    func reopenWeek() {
        weekPlan.isWeekComplete = false
        weekPlan.weekCompletedAt = nil
        SyncMetadata.stampSave(&weekPlan)
        persistWeek()
    }

    @discardableResult
    func saveWeeklyReflection(
        weekRating: Int,
        fatigue: FatigueLevel,
        recovery: RecoveryLevel,
        sleepQuality: SleepQualityLevel,
        motivation: MotivationLevel,
        mood: MoodLevel,
        lifeStress: LifeStressLevel,
        whatWentWell: String?,
        nextWeekChanges: String?,
        issueReviews: [(issueID: UUID, trend: WeeklyIssueTrend)]
    ) -> WeeklyReflection {
        let key = currentWeekKey
        let well = whatWentWell.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let next = nextWeekChanges.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }

        let reflection: WeeklyReflection
        if let idx = weeklyReflections.firstIndex(where: { !$0.isDeleted && $0.weekKey == key }) {
            var updated = WeeklyReflection(
                id: weeklyReflections[idx].id,
                weekKey: key,
                weekRating: weekRating,
                fatigue: fatigue,
                recovery: recovery,
                sleepQuality: sleepQuality,
                motivation: motivation,
                mood: mood,
                lifeStress: lifeStress,
                whatWentWell: well,
                nextWeekChanges: next,
                schemaVersion: weeklyReflections[idx].schemaVersion,
                createdAt: weeklyReflections[idx].createdAt,
                updatedAt: weeklyReflections[idx].updatedAt,
                etag: weeklyReflections[idx].etag
            )
            SyncMetadata.stampSave(&updated)
            weeklyReflections[idx] = updated
            reflection = updated
        } else {
            var created = WeeklyReflection(
                weekKey: key,
                weekRating: weekRating,
                fatigue: fatigue,
                recovery: recovery,
                sleepQuality: sleepQuality,
                motivation: motivation,
                mood: mood,
                lifeStress: lifeStress,
                whatWentWell: well,
                nextWeekChanges: next
            )
            SyncMetadata.stampNewRecord(&created)
            weeklyReflections.append(created)
            reflection = created
        }
        persistWeeklyReflections()

        for reviewInput in issueReviews {
            let resulting: PhysicalIssueStatus = reviewInput.trend == .resolved ? .resolved : .active
            if let existing = weeklyIssueReviews.firstIndex(where: {
                !$0.isDeleted && $0.weekKey == key && $0.physicalIssueID == reviewInput.issueID
            }) {
                var review = WeeklyIssueReview(
                    id: weeklyIssueReviews[existing].id,
                    physicalIssueID: reviewInput.issueID,
                    weekKey: key,
                    weeklyReflectionID: reflection.id,
                    weeklyTrend: reviewInput.trend,
                    resultingStatus: resulting,
                    schemaVersion: weeklyIssueReviews[existing].schemaVersion,
                    createdAt: weeklyIssueReviews[existing].createdAt,
                    etag: weeklyIssueReviews[existing].etag
                )
                SyncMetadata.stampSave(&review)
                weeklyIssueReviews[existing] = review
            } else {
                var review = WeeklyIssueReview(
                    physicalIssueID: reviewInput.issueID,
                    weekKey: key,
                    weeklyReflectionID: reflection.id,
                    weeklyTrend: reviewInput.trend,
                    resultingStatus: resulting
                )
                SyncMetadata.stampNewRecord(&review)
                weeklyIssueReviews.append(review)
            }

            if let issueIdx = physicalIssues.firstIndex(where: { $0.id == reviewInput.issueID }) {
                if reviewInput.trend == .resolved {
                    physicalIssues[issueIdx].status = .resolved
                    physicalIssues[issueIdx].resolvedAt = Date()
                }
                SyncMetadata.stampSave(&physicalIssues[issueIdx])
            }
        }
        persistWeeklyIssueReviews()
        persistPhysicalIssues()
        return reflection
    }
}
