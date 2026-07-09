import Foundation

/// Reads and writes week plan JSON in legacy or migrated format.
enum WeekPlanPersistence {

    static func read(from url: URL, fileManager: FileManager = .default) throws -> MigratedWeekPlan {
        let data = try Data(contentsOf: url)
        let modificationDate = fileModificationDate(for: url, fileManager: fileManager)
        return try decode(data, fileModificationDate: modificationDate)
    }

    /// Dual-read: migrated payloads decode directly; legacy payloads are converted in memory.
    static func decode(_ data: Data, fileModificationDate: Date? = nil) throws -> MigratedWeekPlan {
        if jsonLooksLikeMigratedWeekPlan(data) {
            let decoder = jsonDecoder()
            var plan = try decoder.decode(MigratedWeekPlan.self, from: data)
            SyncMetadata.stampLegacy(&plan, fallbackTimestamp: fileModificationDate ?? Date())
            return plan
        }

        let decoder = jsonDecoder()
        let legacy = try decoder.decode(WeekPlan.self, from: data)
        var migrated = WeekPlanMapper.migratedWeekPlan(from: legacy, fileModificationDate: fileModificationDate)
        SyncMetadata.stampLegacy(&migrated, fallbackTimestamp: fileModificationDate ?? legacy.updatedAt ?? Date())
        return migrated
    }

    static func write(_ plan: MigratedWeekPlan, to url: URL) throws {
        var stamped = plan
        stamped.formatVersion = MigratedWeekPlan.formatVersion
        stamped.updatedAt = Date()

        let encoder = jsonEncoder()
        let data = try encoder.encode(stamped)
        try data.write(to: url, options: .atomic)
    }

    static func legacyWeekPlan(from url: URL, fileManager: FileManager = .default) throws -> WeekPlan {
        let migrated = try read(from: url, fileManager: fileManager)
        return WeekPlanMapper.legacyWeekPlan(from: migrated)
    }

    static func fileModificationDate(for url: URL, fileManager: FileManager = .default) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }

    private static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }

    private static func jsonLooksLikeMigratedWeekPlan(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if object["formatVersion"] != nil { return true }
        guard let days = object["days"] as? [[String: Any]], let firstDay = days.first else {
            return false
        }
        return firstDay["workouts"] != nil
    }
}
