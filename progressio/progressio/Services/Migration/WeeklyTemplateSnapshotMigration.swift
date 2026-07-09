import Foundation

enum WeeklyTemplateSnapshotMigration {

    static func migrateAll(fileManager: FileManager = .default) throws {
        let url = LegacyDataDecoder.weeklyTemplatesURL()
        guard fileManager.fileExists(atPath: url.path) else { return }

        let data = try Data(contentsOf: url)
        guard TemplatePersistence.jsonNeedsWeeklyTemplateSnapshotMigration(data) else {
            print("⏭️ weeklyTemplates.json already uses workoutEntries snapshots.")
            return
        }

        _ = try MigrationBackup.backupFile(at: url, fileManager: fileManager)
        let templates = try TemplatePersistence.decodeWeeklyTemplates(data)
        try TemplatePersistence.saveWeeklyTemplates(templates, to: url)
        let entryCount = templates.reduce(0) { $0 + $1.days.reduce(0) { $0 + $1.workoutEntries.count } }
        print("✅ Migrated weeklyTemplates.json to workoutEntries snapshots (\(templates.count) template(s), \(entryCount) entr(y/ies)).")
    }
}
