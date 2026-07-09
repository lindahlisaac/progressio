import Foundation

enum EnduranceTemplateMigration {

    static func migrateAll(fileManager: FileManager = .default) throws {
        let templatesURL = LegacyDataDecoder.templatesURL()
        let enduranceURL = LegacyDataDecoder.enduranceTemplatesURL()

        guard fileManager.fileExists(atPath: templatesURL.path) else { return }

        let allTemplates = try TemplatePersistence.loadTemplates(from: templatesURL)
        let legacyEnduranceTemplates = allTemplates.filter { $0.category == .endurance }
        let strengthTemplates = allTemplates.filter { $0.category == .strength }

        var enduranceTemplates = (try? EnduranceTemplatePersistence.load(from: enduranceURL)) ?? []
        let existingIDs = Set(enduranceTemplates.map(\.id))
        var migratedCount = 0

        for legacy in legacyEnduranceTemplates where !existingIDs.contains(legacy.id) {
            enduranceTemplates.append(EnduranceTemplate.fromLegacyStrengthTemplate(legacy))
            migratedCount += 1
        }

        let needsStrengthRewrite = !legacyEnduranceTemplates.isEmpty || strengthTemplates.count != allTemplates.count
        if needsStrengthRewrite {
            _ = try MigrationBackup.backupFile(at: templatesURL, fileManager: fileManager)
            try TemplatePersistence.saveTemplates(strengthTemplates, to: templatesURL)
        }

        if migratedCount > 0 || !fileManager.fileExists(atPath: enduranceURL.path) {
            if migratedCount > 0 {
                _ = try MigrationBackup.backupFile(at: enduranceURL, fileManager: fileManager)
            }
            try EnduranceTemplatePersistence.save(enduranceTemplates, to: enduranceURL)
        }

        print("✅ Endurance template migration: \(migratedCount) endurance template(s) moved, \(strengthTemplates.count) strength template(s) retained.")
    }
}

enum EnduranceTemplatePersistence {
    static func load(from url: URL = LegacyDataDecoder.enduranceTemplatesURL()) throws -> [EnduranceTemplate] {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> [EnduranceTemplate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var templates = try decoder.decode([EnduranceTemplate].self, from: data)
        let fallback = Date()
        for index in templates.indices {
            MetadataStamping.stamp(&templates[index], fallbackTimestamp: fallback)
        }
        return templates
    }

    static func save(_ templates: [EnduranceTemplate], to url: URL = LegacyDataDecoder.enduranceTemplatesURL()) throws {
        var stamped = templates
        let now = Date()
        for index in stamped.indices {
            MetadataStamping.stamp(&stamped[index], fallbackTimestamp: now)
            stamped[index].updatedAt = now
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stamped)
        try data.write(to: url, options: .atomic)
    }
}
