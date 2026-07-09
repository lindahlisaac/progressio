import Foundation

enum TemplatePersistence {
    static func loadTemplates(from url: URL = LegacyDataDecoder.templatesURL()) throws -> [StrengthTemplate] {
        let data = try Data(contentsOf: url)
        return try decodeTemplates(data)
    }

    static func decodeTemplates(_ data: Data) throws -> [StrengthTemplate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var templates = try decoder.decode([StrengthTemplate].self, from: data)
        let fallback = Date()
        for index in templates.indices {
            MetadataStamping.stamp(&templates[index], fallbackTimestamp: fallback)
        }
        return templates
    }

    static func saveTemplates(_ templates: [StrengthTemplate], to url: URL = LegacyDataDecoder.templatesURL()) throws {
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

    static func loadWeeklyTemplates(from url: URL = LegacyDataDecoder.weeklyTemplatesURL()) throws -> [WeeklyTemplate] {
        let data = try Data(contentsOf: url)
        return try decodeWeeklyTemplates(data)
    }

    static func decodeWeeklyTemplates(_ data: Data) throws -> [WeeklyTemplate] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var templates = try decoder.decode([WeeklyTemplate].self, from: data)
        let fallback = Date()
        for index in templates.indices {
            MetadataStamping.stamp(&templates[index], fallbackTimestamp: fallback)
        }
        return templates
    }

    static func saveWeeklyTemplates(
        _ templates: [WeeklyTemplate],
        to url: URL = LegacyDataDecoder.weeklyTemplatesURL()
    ) throws {
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

    static func jsonNeedsTemplateMetadataMigration(_ data: Data) -> Bool {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = array.first else {
            return false
        }
        return first["schemaVersion"] == nil
    }

    static func jsonNeedsWeeklyTemplateMetadataMigration(_ data: Data) -> Bool {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = array.first else {
            return false
        }
        return first["schemaVersion"] == nil
    }

    /// True when any day still stores legacy `sessions` instead of `workoutEntries`.
    static func jsonNeedsWeeklyTemplateSnapshotMigration(_ data: Data) -> Bool {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }
        for template in array {
            guard let days = template["days"] as? [[String: Any]] else { continue }
            for day in days {
                if day["sessions"] != nil, day["workoutEntries"] == nil {
                    return true
                }
            }
        }
        return false
    }
}
