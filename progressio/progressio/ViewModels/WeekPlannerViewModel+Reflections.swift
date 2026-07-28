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

    var resolvedPhysicalIssues: [PhysicalIssue] {
        physicalIssues
            .filter { !$0.isDeleted && $0.status == .resolved }
            .sorted { ($0.resolvedAt ?? $0.updatedAt ?? .distantPast) > ($1.resolvedAt ?? $1.updatedAt ?? .distantPast) }
    }

    func matchingActiveIssues(area: BodyArea, side: BodySide) -> [PhysicalIssue] {
        activePhysicalIssues.filter { $0.bodyArea == area && $0.side == side }
    }

    /// All non-deleted reports for an issue, oldest → newest.
    func issueReports(forIssueID issueID: UUID) -> [ActivityIssueReport] {
        activityIssueReports
            .filter { !$0.isDeleted && $0.physicalIssueID == issueID }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    func latestIssueReport(forIssueID issueID: UUID) -> ActivityIssueReport? {
        issueReports(forIssueID: issueID).last
    }

    /// Weekly reviews for an issue, oldest → newest by weekKey.
    func weeklyReviews(forIssueID issueID: UUID) -> [WeeklyIssueReview] {
        weeklyIssueReviews
            .filter { !$0.isDeleted && $0.physicalIssueID == issueID }
            .sorted { $0.weekKey < $1.weekKey }
    }

    /// Best-effort workout title/date for a report (current week + local history scan).
    func workoutContext(forWorkoutID workoutID: UUID) -> (title: String, date: Date)? {
        if let match = weekPlan.days.flatMap({ day in
            day.activeWorkouts.map { (day.date, $0) }
        }).first(where: { $0.1.id == workoutID }) {
            return (match.1.title, match.1.completedValues.completedAt ?? match.0)
        }
        if let entry = historyEntries().first(where: { $0.workout.id == workoutID }) {
            return (entry.workout.title, entry.workout.completedValues.completedAt ?? entry.dayDate)
        }
        return nil
    }

    func resolvePhysicalIssue(id: UUID, note: String? = nil) {
        guard let idx = physicalIssues.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return }
        physicalIssues[idx].status = .resolved
        physicalIssues[idx].resolvedAt = Date()
        if let note {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                physicalIssues[idx].optionalNotes = trimmed
            }
        }
        SyncMetadata.stampSave(&physicalIssues[idx])
        persistPhysicalIssues()
    }

    func reopenPhysicalIssue(id: UUID) {
        guard let idx = physicalIssues.firstIndex(where: { $0.id == id && !$0.isDeleted }) else { return }
        physicalIssues[idx].status = .active
        physicalIssues[idx].resolvedAt = nil
        SyncMetadata.stampSave(&physicalIssues[idx])
        persistPhysicalIssues()
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
        reflectionKind: ActivityReflectionKind = .standard,
        feel: SessionFeel?,
        sessionRPE: Int?,
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
                reflectionKind: reflectionKind,
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
            reflectionKind: reflectionKind,
            feel: feel,
            sessionRPE: sessionRPE,
            performanceNotes: notes
        )
        SyncMetadata.stampNewRecord(&created)
        activityReflections.append(created)
        persistActivityReflections()
        return created
    }

    /// Ensures status is `.completed` after an optional reflection Save/Keep.
    /// Safe to call when already completed (idempotent).
    func finalizeComplete(workoutID: UUID) {
        setWorkoutStatus(workoutID: workoutID, status: .completed)
    }

    /// Finalizes a skip with optional light reflection (reason + optional discomfort). No fake RPE.
    @discardableResult
    func finalizeSkip(
        workoutID: UUID,
        reason: String,
        discomfort: (
            area: BodyArea,
            side: BodySide,
            painLevel: Int,
            timing: DiscomfortTiming,
            trend: DiscomfortTrend,
            existingIssueID: UUID?,
            newIssueTitle: String?
        )? = nil
    ) -> ActivityReflection? {
        setWorkoutStatus(workoutID: workoutID, status: .skipped, note: reason)
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        // No slim reflection when user skips with no reason and no discomfort.
        guard !trimmedReason.isEmpty || discomfort != nil else { return nil }

        guard let reflection = saveActivityReflection(
            workoutID: workoutID,
            reflectionKind: .skip,
            feel: nil,
            sessionRPE: nil,
            performanceNotes: trimmedReason.isEmpty ? nil : trimmedReason,
            overwriteExisting: true
        ) else { return nil }

        if let discomfort {
            let issue: PhysicalIssue
            if let existingID = discomfort.existingIssueID,
               let existing = physicalIssues.first(where: { $0.id == existingID && !$0.isDeleted }) {
                issue = existing
            } else {
                issue = createPhysicalIssue(
                    area: discomfort.area,
                    side: discomfort.side,
                    title: discomfort.newIssueTitle,
                    notes: nil
                )
            }
            _ = replaceActivityIssueReport(
                forWorkoutID: workoutID,
                physicalIssueID: issue.id,
                activityReflectionID: reflection.id,
                painLevel: discomfort.painLevel,
                timing: discomfort.timing,
                trend: discomfort.trend
            )
        } else {
            softDeleteActivityIssueReports(forWorkoutID: workoutID)
        }
        return reflection
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
