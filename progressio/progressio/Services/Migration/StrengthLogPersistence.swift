import Foundation

/// Migration / legacy-only helpers for historical `strengthlog-{uuid}.json` files.
///
/// **Production code outside `Services/Migration/` must not call this.**
/// Strength logging lives on `Workout.plannedValues` / `completedValues` snapshots
/// inside the week plan (Task 021 / 031). These APIs remain for embed migrations
/// and a best-effort orphan file sweep only.
enum StrengthLogPersistence {

    static func strengthLogURL(for sessionID: UUID, fileManager: FileManager = .default) -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("\(LegacyDataDecoder.strengthLogPrefix)\(sessionID.uuidString).json")
    }

    static func load(from url: URL) -> StrengthLogState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try decode(from: url)
        } catch {
            print("Failed to load strength log at \(url): \(error)")
            return nil
        }
    }

    static func decode(from url: URL, fileManager: FileManager = .default) throws -> StrengthLogState {
        let data = try Data(contentsOf: url)
        return try decode(data, fileModificationDate: fileModificationDate(for: url, fileManager: fileManager))
    }

    static func decode(_ data: Data, fileModificationDate: Date? = nil) throws -> StrengthLogState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var state = try decoder.decode(StrengthLogState.self, from: data)
        MetadataStamping.stamp(&state, fallbackTimestamp: fileModificationDate ?? Date())
        return state
    }

    static func save(_ state: StrengthLogState, to url: URL) throws {
        var stamped = state
        MetadataStamping.stamp(&stamped, fallbackTimestamp: Date())
        stamped.updatedAt = Date()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stamped)
        try data.write(to: url, options: .atomic)
    }

    static func jsonNeedsMetadataMigration(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["schemaVersion"] == nil
    }

    static func fileModificationDate(for url: URL, fileManager: FileManager = .default) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }

    /// Deletes leftover `strengthlog-*.json` when safe: matching workout already has a
    /// completed strength snapshot, or no matching workout exists on disk.
    /// Keeps files when a workout exists without an embedded snapshot (unrecovered data).
    @discardableResult
    static func sweepOrphanFiles(fileManager: FileManager = .default) -> Int {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let prefix = LegacyDataDecoder.strengthLogPrefix
        guard let contents = try? fileManager.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var workoutIndex: [UUID: Bool] = [:] // id → has completed strength snapshot
        let weekStore = FileWeekPlanStore()
        for weekStart in WeekPlanFileIndex.allWeekStarts(fileManager: fileManager) {
            guard let week = weekStore.loadWeek(start: weekStart) else { continue }
            for workout in week.days.flatMap(\.workouts) where workout.activityType == .strength {
                workoutIndex[workout.id] = workout.completedValues.completedStrengthRoutineSnapshot != nil
            }
        }

        var removed = 0
        for url in contents {
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix(prefix) else { continue }
            let idString = String(name.dropFirst(prefix.count))
            guard let workoutID = UUID(uuidString: idString) else { continue }

            let shouldDelete: Bool
            if let hasSnapshot = workoutIndex[workoutID] {
                shouldDelete = hasSnapshot
            } else {
                shouldDelete = true // no matching workout
            }
            guard shouldDelete else { continue }

            do {
                try fileManager.removeItem(at: url)
                removed += 1
            } catch {
                print("⚠️ Failed to remove orphan strength log \(url.lastPathComponent): \(error)")
            }
        }
        if removed > 0 {
            print("🧹 Removed \(removed) orphan strengthlog-*.json file(s)")
        }
        return removed
    }
}
