import Foundation

/// Migrates local `weekplan-*.json` files from legacy sessions to workouts.
enum WeekPlanMigration {

    static func migrateAllWeekPlanFiles(fileManager: FileManager = .default) throws -> Int {
        let urls = LegacyDataDecoder.weekPlanURLs(fileManager: fileManager)
        var migratedCount = 0

        for url in urls {
            if try migrateWeekPlanFile(at: url, fileManager: fileManager) {
                migratedCount += 1
            }
        }

        print("✅ Week plan migration: processed \(urls.count) file(s), wrote \(migratedCount) migrated file(s).")
        return migratedCount
    }

    @discardableResult
    static func migrateWeekPlanFile(at url: URL, fileManager: FileManager = .default) throws -> Bool {
        let data = try Data(contentsOf: url)

        if jsonLooksLikeMigratedWeekPlan(data) {
            print("⏭️ Week plan already migrated: \(url.lastPathComponent)")
            return false
        }

        _ = try MigrationBackup.backupFile(at: url, fileManager: fileManager)

        let legacy = try LegacyDataDecoder.decodeWeekPlan(from: url)
        let modificationDate = WeekPlanPersistence.fileModificationDate(for: url, fileManager: fileManager)
        let migrated = WeekPlanMapper.migratedWeekPlan(from: legacy, fileModificationDate: modificationDate)
        try WeekPlanPersistence.write(migrated, to: url)

        print("✅ Migrated week plan: \(url.lastPathComponent) (\(migrated.days.flatMap(\.workouts).count) workouts)")
        return true
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
