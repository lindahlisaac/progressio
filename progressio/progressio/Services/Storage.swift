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

protocol EnduranceTemplateStore {
    func loadTemplates() -> [EnduranceTemplate]?
    func save(_ templates: [EnduranceTemplate])
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

protocol ImportedHealthWorkoutReferenceStore {
    func loadReferences() -> [ImportedHealthWorkoutReference]
    func save(_ references: [ImportedHealthWorkoutReference])
}

protocol PeriodizedBlockStore {
    func loadBlocks() -> [PeriodizedBlockTemplate]
    func save(_ blocks: [PeriodizedBlockTemplate])
}

// MARK: - File-backed stores

struct FileTemplateStore: TemplateStore {
    private let url = StoragePaths.file("templates.json")

    func loadTemplates() -> [StrengthTemplate]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try TemplatePersistence.loadTemplates(from: url)
        } catch {
            print("Failed to load templates: \(error)")
            return nil
        }
    }

    func save(_ templates: [StrengthTemplate]) {
        do {
            try TemplatePersistence.saveTemplates(templates, to: url)
        } catch {
            print("Failed to persist templates: \(error)")
        }
    }
}

struct FileEnduranceTemplateStore: EnduranceTemplateStore {
    private let url = StoragePaths.file("enduranceTemplates.json")

    func loadTemplates() -> [EnduranceTemplate]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try EnduranceTemplatePersistence.load(from: url)
        } catch {
            print("Failed to load endurance templates: \(error)")
            return nil
        }
    }

    func save(_ templates: [EnduranceTemplate]) {
        do {
            try EnduranceTemplatePersistence.save(templates, to: url)
        } catch {
            print("Failed to persist endurance templates: \(error)")
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
            var legacy = WeekPlanMapper.weekPlan(from: migrated)
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
            var runs = try decoder.decode([UnattachedRun].self, from: data)
            let fallback = Date()
            for index in runs.indices {
                SyncMetadata.stampLegacy(&runs[index], fallbackTimestamp: fallback)
            }
            return runs
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
            return try TemplatePersistence.loadWeeklyTemplates(from: url)
        } catch {
            print("Failed to load weekly templates: \(error)")
            return []
        }
    }

    func save(_ templates: [WeeklyTemplate]) {
        do {
            try TemplatePersistence.saveWeeklyTemplates(templates, to: url)
            print("💾 Persisted \(templates.count) weekly templates to \(url.path)")
        } catch {
            print("❌ Failed to persist weekly templates: \(error)")
        }
    }
}

struct FileImportedHealthWorkoutReferenceStore: ImportedHealthWorkoutReferenceStore {
    private let url = StoragePaths.file("importedHealthWorkouts.json")

    func loadReferences() -> [ImportedHealthWorkoutReference] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ImportedHealthWorkoutReference].self, from: data)
        } catch {
            print("Failed to load imported HealthKit references: \(error)")
            return []
        }
    }

    func save(_ references: [ImportedHealthWorkoutReference]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(references)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist imported HealthKit references: \(error)")
        }
    }
}

struct FilePeriodizedBlockStore: PeriodizedBlockStore {
    private let url = StoragePaths.file("periodizedBlocks.json")

    func loadBlocks() -> [PeriodizedBlockTemplate] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PeriodizedBlockTemplate].self, from: data)
        } catch {
            print("Failed to load periodized blocks: \(error)")
            return []
        }
    }

    func save(_ blocks: [PeriodizedBlockTemplate]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(blocks)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist periodized blocks: \(error)")
        }
    }
}

enum WeekPlanFileIndex {
    private static let prefix = "weekplan-"
    private static let suffix = ".json"

    private static let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    /// Week start dates for all on-disk week plan files (local Documents).
    static func allWeekStarts(fileManager: FileManager = .default) -> [Date] {
        let dir = StoragePaths.baseDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return contents.compactMap { url -> Date? in
            let name = url.lastPathComponent
            guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
            let dateString = String(name.dropFirst(prefix.count).dropLast(suffix.count))
            return dateFormatter.date(from: dateString)
        }
        .sorted(by: >)
    }
}
