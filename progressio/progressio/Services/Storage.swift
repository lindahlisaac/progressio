import Foundation

enum StoragePaths {
    static let baseDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("progressio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                print("⚠️ Failed to create storage directory \(dir.path): \(error)")
            }
        }
        return dir
    }()

    static func file(_ name: String) -> URL {
        baseDirectory.appendingPathComponent(name)
    }
}

// MARK: - Protocols

protocol TemplateStore {
    func loadTemplates() -> [StrengthTemplate]?
    func save(_ templates: [StrengthTemplate])
}

protocol WeekPlanStore {
    func loadWeek(start: Date) -> WeekPlan?
    func save(_ week: WeekPlan, start: Date)
    func fileURL(for start: Date) -> URL
}

protocol UnattachedRunStore {
    func loadRuns() -> [UnattachedRun]
    func save(_ runs: [UnattachedRun])
}

protocol WeeklyTemplateStore {
    func loadTemplates() -> [WeeklyTemplate]
    func save(_ templates: [WeeklyTemplate])
}

// MARK: - File-backed stores

struct FileTemplateStore: TemplateStore {
    private let url = StoragePaths.file("templates.json")

    func loadTemplates() -> [StrengthTemplate]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([StrengthTemplate].self, from: data)
        } catch {
            print("Failed to load templates: \(error)")
            return nil
        }
    }

    func save(_ templates: [StrengthTemplate]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(templates)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist templates: \(error)")
        }
    }
}

struct FileWeekPlanStore: WeekPlanStore {
    private let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    func loadWeek(start: Date) -> WeekPlan? {
        let url = fileURL(for: start)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let migrated = try WeekPlanPersistence.read(from: url)
            var legacy = WeekPlanMapper.legacyWeekPlan(from: migrated)
            if legacy.updatedAt == nil {
                legacy.updatedAt = migrated.updatedAt
            }
            return legacy
        } catch {
            print("Failed to load week: \(error)")
            return nil
        }
    }

    func save(_ week: WeekPlan, start: Date) {
        do {
            let migrated = WeekPlanMapper.migratedWeekPlan(from: week)
            var stamped = migrated
            stamped.updatedAt = Date()
            let url = fileURL(for: start)
            try WeekPlanPersistence.write(stamped, to: url)
        } catch {
            print("Failed to persist week: \(error)")
        }
    }

    func fileURL(for start: Date) -> URL {
        StoragePaths.file("weekplan-\(dateFormatter.string(from: start)).json")
    }
}

struct FileUnattachedRunStore: UnattachedRunStore {
    private let url = StoragePaths.file("unattachedRuns.json")

    func loadRuns() -> [UnattachedRun] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([UnattachedRun].self, from: data)
        } catch {
            print("Failed to load unattached runs: \(error)")
            return []
        }
    }

    func save(_ runs: [UnattachedRun]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(runs)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist unattached runs: \(error)")
        }
    }
}

struct FileWeeklyTemplateStore: WeeklyTemplateStore {
    private let url = StoragePaths.file("weeklyTemplates.json")

    func loadTemplates() -> [WeeklyTemplate] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WeeklyTemplate].self, from: data)
        } catch {
            print("Failed to load weekly templates: \(error)")
            return []
        }
    }

    func save(_ templates: [WeeklyTemplate]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(templates)
            try data.write(to: url, options: .atomic)
            print("💾 Persisted \(templates.count) weekly templates to \(url.path)")
        } catch {
            print("❌ Failed to persist weekly templates: \(error)")
        }
    }
}
