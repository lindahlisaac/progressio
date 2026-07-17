import Foundation

/// Embeds `strengthlog-*.json` into workout `completedValues.completedStrengthRoutineSnapshot`
/// and removes the standalone files afterward.
enum StrengthLogEmbedMigration {
    static func migrateAll(fileManager: FileManager = .default) throws {
        let weekStore = FileWeekPlanStore()
        var migratedFiles = 0

        for weekStart in WeekPlanFileIndex.allWeekStarts(fileManager: fileManager) {
            guard var plan = weekStore.loadWeek(start: weekStart) else { continue }
            var changed = false

            for dayIndex in plan.days.indices {
                for workoutIndex in plan.days[dayIndex].workouts.indices {
                    let workout = plan.days[dayIndex].workouts[workoutIndex]
                    guard !workout.metadata.isDeleted else { continue }
                    guard workout.activityType == .strength else { continue }
                    guard workout.completedValues.completedStrengthRoutineSnapshot == nil else {
                        // Snapshot already present — delete orphan file if any.
                        removeLogFile(for: workout.id, fileManager: fileManager)
                        continue
                    }

                    let logURL = StrengthLogPersistence.strengthLogURL(for: workout.id, fileManager: fileManager)
                    guard let log = StrengthLogPersistence.load(from: logURL) else { continue }

                    let snapshot = TemplateSnapshot.completedSnapshot(from: log.exercises)
                    plan.days[dayIndex].workouts[workoutIndex].completedValues.completedStrengthRoutineSnapshot = snapshot
                    if log.isCompleted {
                        if plan.days[dayIndex].workouts[workoutIndex].status == .planned {
                            plan.days[dayIndex].workouts[workoutIndex].status = .completed
                        }
                        if plan.days[dayIndex].workouts[workoutIndex].completedValues.completedAt == nil {
                            plan.days[dayIndex].workouts[workoutIndex].completedValues.completedAt = Date()
                        }
                    }
                    changed = true
                    removeLogFile(for: workout.id, fileManager: fileManager)
                    migratedFiles += 1
                }
            }

            if changed {
                weekStore.save(plan, start: weekStart)
            }
        }

        // Sweep any remaining orphan strength log files in Documents.
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let contents = try? fileManager.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for url in contents where url.lastPathComponent.hasPrefix(LegacyDataDecoder.strengthLogPrefix) {
                try? fileManager.removeItem(at: url)
            }
        }

        print("✅ Strength log embed migration complete (\(migratedFiles) log(s) embedded).")
    }

    private static func removeLogFile(for workoutID: UUID, fileManager: FileManager) {
        let url = StrengthLogPersistence.strengthLogURL(for: workoutID, fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }
}
