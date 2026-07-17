import Foundation

// Simple last-writer-wins syncing stores that wrap local file cache + CloudKit.
// Assumes cloud errors are non-fatal; will keep local cache and try to push best-effort.
// Soft-deleted records remain in payloads so tombstones propagate across devices.

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
        let merged = SyncRecordMerge.mergeByID(
            local: localTemplates,
            remote: cloudTemplates,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ templates: [StrengthTemplate]) {
        // Callers stamp mutated records; re-stamping the whole array on every save
        // forced full CloudKit rewrites and queued duplicate payloads.
        local.save(templates)
        cloud.save(templates)
    }
}

struct SyncingEnduranceTemplateStore: EnduranceTemplateStore {
    private let local: EnduranceTemplateStore
    private let cloud: EnduranceTemplateStore

    init(local: EnduranceTemplateStore = FileEnduranceTemplateStore(), cloud: EnduranceTemplateStore = CloudEnduranceTemplateStore()) {
        self.local = local
        self.cloud = cloud
    }

    func loadTemplates() -> [EnduranceTemplate]? {
        let localTemplates = local.loadTemplates() ?? []
        let cloudTemplates = cloud.loadTemplates() ?? []
        let merged = SyncRecordMerge.mergeByID(
            local: localTemplates,
            remote: cloudTemplates,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ templates: [EnduranceTemplate]) {
        local.save(templates)
        cloud.save(templates)
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
        let merged = SyncRecordMerge.mergeByID(
            local: localTemplates,
            remote: cloudTemplates,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ templates: [WeeklyTemplate]) {
        local.save(templates)
        cloud.save(templates)
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
        let merged = SyncRecordMerge.mergeByID(
            local: localRuns,
            remote: cloudRuns,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ runs: [UnattachedRun]) {
        local.save(runs)
        cloud.save(runs)
    }
}

struct SyncingImportedHealthWorkoutReferenceStore: ImportedHealthWorkoutReferenceStore {
    private let local: ImportedHealthWorkoutReferenceStore
    private let cloud: ImportedHealthWorkoutReferenceStore

    init(
        local: ImportedHealthWorkoutReferenceStore = FileImportedHealthWorkoutReferenceStore(),
        cloud: ImportedHealthWorkoutReferenceStore = CloudImportedHealthWorkoutReferenceStore()
    ) {
        self.local = local
        self.cloud = cloud
    }

    func loadReferences() -> [ImportedHealthWorkoutReference] {
        let localRefs = local.loadReferences()
        let cloudRefs = cloud.loadReferences()
        let merged = SyncRecordMerge.mergeByID(
            local: localRefs,
            remote: cloudRefs,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ references: [ImportedHealthWorkoutReference]) {
        local.save(references)
        cloud.save(references)
    }
}

struct SyncingPeriodizedBlockStore: PeriodizedBlockStore {
    private let local: PeriodizedBlockStore
    private let cloud: PeriodizedBlockStore

    init(
        local: PeriodizedBlockStore = FilePeriodizedBlockStore(),
        cloud: PeriodizedBlockStore = CloudPeriodizedBlockStore()
    ) {
        self.local = local
        self.cloud = cloud
    }

    func loadBlocks() -> [PeriodizedBlockTemplate] {
        let localBlocks = local.loadBlocks()
        let cloudBlocks = cloud.loadBlocks()
        let merged = SyncRecordMerge.mergeByID(
            local: localBlocks,
            remote: cloudBlocks,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
        local.save(merged)
        return merged
    }

    func save(_ blocks: [PeriodizedBlockTemplate]) {
        local.save(blocks)
        cloud.save(blocks)
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
        local.save(week, start: start)
        cloud.save(week, start: start)
    }

    func fileURL(for start: Date) -> URL {
        local.fileURL(for: start)
    }

    private func merge(local: WeekPlan?, remote: WeekPlan?) -> WeekPlan? {
        switch (local, remote) {
        case (nil, nil):
            return nil
        case let (localWeek?, nil):
            return localWeek
        case let (nil, remoteWeek?):
            return remoteWeek
        case let (localWeek?, remoteWeek?):
            return SyncRecordMerge.pick(
                local: localWeek,
                remote: remoteWeek,
                updatedAt: \.updatedAt,
                isDeleted: \.isDeleted
            )
        }
    }
}
