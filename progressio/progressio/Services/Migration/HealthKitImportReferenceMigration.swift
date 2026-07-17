import Foundation

/// Seeds `ImportedHealthWorkoutReference` from existing linked/unattached HealthKit UUIDs
/// and soft-deletes duplicate unattached runs that share a UUID.
enum HealthKitImportReferenceMigration {
    static func migrateAll(fileManager: FileManager = .default) throws {
        var referencesByUUID: [String: ImportedHealthWorkoutReference] = [:]
        let existingStore = FileImportedHealthWorkoutReferenceStore()
        for existing in existingStore.loadReferences() where !existing.isDeleted {
            referencesByUUID[existing.healthKitUUID.lowercased()] = existing
        }

        func upsert(uuid: String, linkedWorkoutId: UUID?, start: Date?, activityType: ActivityType) {
            let key = uuid.lowercased()
            if var existing = referencesByUUID[key] {
                if existing.linkedWorkoutId == nil {
                    existing.linkedWorkoutId = linkedWorkoutId
                }
                existing.workoutStartDate = existing.workoutStartDate ?? start
                SyncMetadata.stampSave(&existing)
                referencesByUUID[key] = existing
            } else {
                var reference = ImportedHealthWorkoutReference(
                    healthKitUUID: uuid,
                    linkedWorkoutId: linkedWorkoutId,
                    activityType: activityType,
                    workoutStartDate: start
                )
                SyncMetadata.stampNewRecord(&reference)
                referencesByUUID[key] = reference
            }
        }

        for weekStart in WeekPlanFileIndex.allWeekStarts(fileManager: fileManager) {
            guard let plan = FileWeekPlanStore().loadWeek(start: weekStart) else { continue }
            for day in plan.days {
                for workout in day.workouts where !workout.metadata.isDeleted {
                    if let uuid = workout.linkedHealthKitUUID, !uuid.isEmpty {
                        upsert(
                            uuid: uuid,
                            linkedWorkoutId: workout.id,
                            start: workout.completedValues.completedAt ?? workout.plannedDate,
                            activityType: workout.activityType
                        )
                    }
                }
            }
        }

        let unattachedURL = StoragePaths.file("unattachedRuns.json")
        if fileManager.fileExists(atPath: unattachedURL.path) {
            var runs = try LegacyDataDecoder.decodeUnattachedRuns(from: unattachedURL)
            var seenUnattachedUUID = Set<String>()
            var changed = false
            for index in runs.indices {
                guard !runs[index].isDeleted,
                      let uuid = runs[index].detail.hkWorkoutUUID,
                      !uuid.isEmpty
                else { continue }

                let key = uuid.lowercased()
                upsert(
                    uuid: uuid,
                    linkedWorkoutId: nil,
                    start: runs[index].date,
                    activityType: .roadRun
                )

                if seenUnattachedUUID.contains(key) {
                    runs[index] = SyncMetadata.softDelete(runs[index])
                    changed = true
                } else {
                    seenUnattachedUUID.insert(key)
                }
            }
            if changed {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(runs).write(to: unattachedURL, options: .atomic)
            }
        }

        existingStore.save(Array(referencesByUUID.values))
        print("✅ HealthKit import references seeded (\(referencesByUUID.count) UUID(s)).")
    }
}
