import Foundation

// Simple last-writer-wins syncing stores that wrap local file cache + CloudKit.
// Assumes cloud errors are non-fatal; will keep local cache and try to push best-effort.

struct SyncingTemplateStore: TemplateStore {
    private let local: TemplateStore
    private let cloud: TemplateStore

    init(local: TemplateStore = FileTemplateStore(), cloud: TemplateStore = CloudTemplateStore()) {
        self.local = local
        self.cloud = cloud
    }

    func loadTemplates() -> [StrengthTemplate]? {
        let localTemplates = local.loadTemplates() ?? []
        let cloudTemplates = cloud.loadTemplates() ?? []
        let merged = mergeTemplates(local: localTemplates, remote: cloudTemplates)
        local.save(merged)
        return merged
    }

    func save(_ templates: [StrengthTemplate]) {
        let stamped = templates.map { t -> StrengthTemplate in
            var copy = t
            copy.updatedAt = Date()
            return copy
        }
        local.save(stamped)
        cloud.save(stamped)
    }

    private func mergeTemplates(local: [StrengthTemplate], remote: [StrengthTemplate]) -> [StrengthTemplate] {
        var merged: [UUID: StrengthTemplate] = [:]
        for t in local { merged[t.id] = t }
        for r in remote {
            if let existing = merged[r.id] {
                let localDate = existing.updatedAt ?? .distantPast
                let remoteDate = r.updatedAt ?? .distantPast
                merged[r.id] = remoteDate >= localDate ? r : existing
            } else {
                merged[r.id] = r
            }
        }
        return Array(merged.values)
    }
}

struct SyncingWeeklyTemplateStore: WeeklyTemplateStore {
    private let local: WeeklyTemplateStore
    private let cloud: WeeklyTemplateStore

    init(local: WeeklyTemplateStore = FileWeeklyTemplateStore(), cloud: WeeklyTemplateStore = CloudWeeklyTemplateStore()) {
        self.local = local
        self.cloud = cloud
    }

    func loadTemplates() -> [WeeklyTemplate] {
        let localTemplates = local.loadTemplates()
        let cloudTemplates = cloud.loadTemplates()
        let merged = merge(local: localTemplates, remote: cloudTemplates)
        local.save(merged)
        return merged
    }

    func save(_ templates: [WeeklyTemplate]) {
        let stamped = templates.map { t -> WeeklyTemplate in
            var copy = t
            copy.updatedAt = Date()
            return copy
        }
        local.save(stamped)
        cloud.save(stamped)
    }

    private func merge(local: [WeeklyTemplate], remote: [WeeklyTemplate]) -> [WeeklyTemplate] {
        var merged: [UUID: WeeklyTemplate] = [:]
        for t in local { merged[t.id] = t }
        for r in remote {
            if let existing = merged[r.id] {
                let localDate = existing.updatedAt ?? .distantPast
                let remoteDate = r.updatedAt ?? .distantPast
                merged[r.id] = remoteDate >= localDate ? r : existing
            } else {
                merged[r.id] = r
            }
        }
        return Array(merged.values)
    }
}

struct SyncingUnattachedRunStore: UnattachedRunStore {
    private let local: UnattachedRunStore
    private let cloud: UnattachedRunStore

    init(local: UnattachedRunStore = FileUnattachedRunStore(), cloud: UnattachedRunStore = CloudUnattachedRunStore()) {
        self.local = local
        self.cloud = cloud
    }

    func loadRuns() -> [UnattachedRun] {
        let localRuns = local.loadRuns()
        let cloudRuns = cloud.loadRuns()
        let merged = merge(local: localRuns, remote: cloudRuns)
        local.save(merged)
        return merged
    }

    func save(_ runs: [UnattachedRun]) {
        let stamped = runs.map { r -> UnattachedRun in
            var copy = r
            copy.updatedAt = Date()
            return copy
        }
        local.save(stamped)
        cloud.save(stamped)
    }

    private func merge(local: [UnattachedRun], remote: [UnattachedRun]) -> [UnattachedRun] {
        var merged: [UUID: UnattachedRun] = [:]
        for r in local { merged[r.id] = r }
        for r in remote {
            if let existing = merged[r.id] {
                let localDate = existing.updatedAt ?? .distantPast
                let remoteDate = r.updatedAt ?? .distantPast
                merged[r.id] = remoteDate >= localDate ? r : existing
            } else {
                merged[r.id] = r
            }
        }
        return Array(merged.values)
    }
}

struct SyncingWeekPlanStore: WeekPlanStore {
    private let local: WeekPlanStore
    private let cloud: WeekPlanStore

    init(local: WeekPlanStore = FileWeekPlanStore(), cloud: WeekPlanStore = CloudWeekPlanStore()) {
        self.local = local
        self.cloud = cloud
    }

    func loadWeek(start: Date) -> WeekPlan? {
        let localWeek = local.loadWeek(start: start)
        let cloudWeek = cloud.loadWeek(start: start)
        let merged = merge(local: localWeek, remote: cloudWeek)
        if let merged { local.save(merged, start: start) }
        return merged
    }

    func save(_ week: WeekPlan, start: Date) {
        var stamped = week
        stamped.updatedAt = Date()
        local.save(stamped, start: start)
        cloud.save(stamped, start: start)
    }

    func fileURL(for start: Date) -> URL {
        local.fileURL(for: start)
    }

    private func merge(local: WeekPlan?, remote: WeekPlan?) -> WeekPlan? {
        switch (local, remote) {
        case (nil, nil):
            return nil
        case let (l?, nil):
            return l
        case let (nil, r?):
            return r
        case let (l?, r?):
            let lDate = l.updatedAt ?? .distantPast
            let rDate = r.updatedAt ?? .distantPast
            return rDate >= lDate ? r : l
        }
    }
}
