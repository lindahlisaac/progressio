import Foundation

extension WeekPlannerViewModel {

    struct HealthKitImportSummary: Equatable {
        var skippedDuplicates: Int = 0
        var addedUnattached: Int = 0

        var userMessage: String {
            if skippedDuplicates == 0 && addedUnattached == 0 {
                return "No new runs found."
            }
            var parts: [String] = []
            if addedUnattached > 0 {
                parts.append("\(addedUnattached) run(s) ready to attach")
            }
            if skippedDuplicates > 0 {
                parts.append("skipped \(skippedDuplicates) duplicate(s)")
            }
            return "Import: " + parts.joined(separator: ", ") + "."
        }
    }

    /// Imports HealthKit candidates into the Unattached list only (manual attach).
    /// Does not write calendar workouts or queue match prompts.
    @discardableResult
    func processHealthKitCandidates(_ candidates: [HealthKitImportCandidate]) -> HealthKitImportSummary {
        var summary = HealthKitImportSummary()
        guard !candidates.isEmpty else { return summary }

        var known = knownHealthKitUUIDSet()

        for candidate in candidates {
            let uuid = candidate.healthKitUUID
            if !uuid.isEmpty {
                let normalized = uuid.lowercased()
                if known.contains(normalized) {
                    print("HK import: skip known UUID \(uuid)")
                    summary.skippedDuplicates += 1
                    continue
                }
                if addUnattachedRunIfNew(candidate.unattachedRun) {
                    recordImportedReference(
                        healthKitUUID: uuid,
                        linkedWorkoutId: nil,
                        activityType: candidate.activityType,
                        workoutStartDate: candidate.startDate
                    )
                    known.insert(normalized)
                    summary.addedUnattached += 1
                    print("HK import: unattached \(uuid)")
                } else {
                    summary.skippedDuplicates += 1
                }
            } else if addUnattachedRunIfNew(candidate.unattachedRun) {
                summary.addedUnattached += 1
            } else {
                summary.skippedDuplicates += 1
            }
        }

        if summary.addedUnattached > 0 {
            recordHealthKitImportTimestamp()
        }
        return summary
    }

    func isHealthKitUUIDKnown(_ uuid: String) -> Bool {
        knownHealthKitUUIDSet().contains(uuid.lowercased())
    }

    // MARK: - Internals

    /// Local-only UUID index (no CloudKit week fetches — those froze launch and could merge-stale wipe imports).
    private func knownHealthKitUUIDSet() -> Set<String> {
        var known = Set<String>()
        known.formUnion(inflightHealthKitUUIDs)

        for reference in importedHealthReferences where !reference.isDeleted {
            known.insert(reference.healthKitUUID.lowercased())
        }
        for run in unattachedRuns where !run.isDeleted {
            if let uuid = run.detail.hkWorkoutUUID?.lowercased() {
                known.insert(uuid)
            }
        }
        for day in weekPlan.days {
            for workout in day.workouts where !workout.metadata.isDeleted {
                if let uuid = workout.linkedHealthKitUUID?.lowercased() {
                    known.insert(uuid)
                }
            }
        }

        let localWeeks = FileWeekPlanStore()
        for weekStart in WeekPlanFileIndex.allWeekStarts() {
            if calendar.isDate(weekStart, inSameDayAs: currentStartOfWeek) { continue }
            guard let plan = localWeeks.loadWeek(start: weekStart) else { continue }
            for day in plan.days {
                for workout in day.workouts where !workout.metadata.isDeleted {
                    if let uuid = workout.linkedHealthKitUUID?.lowercased() {
                        known.insert(uuid)
                    }
                }
            }
        }
        return known
    }

    func recordImportedReference(
        healthKitUUID: String,
        linkedWorkoutId: UUID?,
        activityType: ActivityType,
        workoutStartDate: Date?
    ) {
        if let existing = importedHealthReferences.firstIndex(where: {
            !$0.isDeleted && $0.healthKitUUID.lowercased() == healthKitUUID.lowercased()
        }) {
            importedHealthReferences[existing].linkedWorkoutId = linkedWorkoutId
            importedHealthReferences[existing].importedAt = Date()
            SyncMetadata.stampSave(&importedHealthReferences[existing])
        } else {
            var reference = ImportedHealthWorkoutReference(
                healthKitUUID: healthKitUUID,
                linkedWorkoutId: linkedWorkoutId,
                activityType: activityType,
                workoutStartDate: workoutStartDate
            )
            SyncMetadata.stampNewRecord(&reference)
            importedHealthReferences.append(reference)
        }
        persistImportedHealthReferences()
    }

    func withWeek(containing date: Date, mutate: (inout WeekPlan) -> Void) {
        let weekStart = calendar.startOfWeek(for: date)
        if calendar.isDate(weekStart, inSameDayAs: currentStartOfWeek) {
            mutate(&weekPlan)
            persistWeek()
            return
        }
        var plan = weekStore.loadWeek(start: weekStart)
            ?? WeekPlannerViewModel.makeEmptyWeek(calendar: calendar, start: weekStart)
        mutate(&plan)
        weekStore.save(plan, start: weekStart)
    }

    @discardableResult
    private func addUnattachedRunIfNew(_ run: UnattachedRun) -> Bool {
        let before = activeUnattachedRuns.count
        importUnattachedRuns([run])
        return activeUnattachedRuns.count > before
    }
}
