import Foundation
import CloudKit

private enum CKConfig {
    static let container = CKContainer.default()
    static let database = CKConfig.container.privateCloudDatabase
}

private enum CKRecordType {
    static let template = "StrengthTemplate"
    static let enduranceTemplate = "EnduranceTemplate"
    static let weeklyTemplate = "WeeklyTemplate"
    static let unattachedRun = "UnattachedRun"
    static let importedHealthWorkout = "ImportedHealthWorkout"
    static let periodizedBlock = "PeriodizedBlockTemplate"
    static let weekPlan = "WeekPlan"
    static let activityReflection = "ActivityReflection"
    static let weeklyReflection = "WeeklyReflection"
    static let physicalIssue = "PhysicalIssue"
    static let activityIssueReport = "ActivityIssueReport"
    static let weeklyIssueReview = "WeeklyIssueReview"
}

private enum CKFields {
    static let payload = "payload"       // Data (JSON)
    static let updatedAt = "updatedAt"   // Date
    static let etag = "etag"             // String
}

// MARK: - Helpers

private func makeRecordID(id: UUID, type: String) -> CKRecord.ID {
    CKRecord.ID(recordName: "\(type)-\(id.uuidString)")
}

private func makeRecordID(name: String, type: String) -> CKRecord.ID {
    CKRecord.ID(recordName: "\(type)-\(name)")
}

private func encodePayload<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(value)
}

private func decodePayload<T: Decodable>(_ data: Data) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: data)
}

// MARK: - Cloud stores

struct CloudTemplateStore: TemplateStore {
    func loadTemplates() -> [StrengthTemplate]? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [StrengthTemplate]?

        let query = CKQuery(recordType: CKRecordType.template, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                // No records yet or record type not created; treat as empty.
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load templates error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: StrengthTemplate = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode template failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ templates: [StrengthTemplate]) {
        let records: [CKRecord] = templates.compactMap { template in
            let record = CKRecord(recordType: CKRecordType.template, recordID: makeRecordID(id: template.id, type: CKRecordType.template))
            do {
                record[CKFields.payload] = try encodePayload(template) as CKRecordValue
                record[CKFields.updatedAt] = (template.updatedAt ?? Date()) as CKRecordValue
                if let etag = template.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode template failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudEnduranceTemplateStore: EnduranceTemplateStore {
    func loadTemplates() -> [EnduranceTemplate]? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [EnduranceTemplate]?

        let query = CKQuery(recordType: CKRecordType.enduranceTemplate, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load endurance templates error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: EnduranceTemplate = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode endurance template failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ templates: [EnduranceTemplate]) {
        let records: [CKRecord] = templates.compactMap { template in
            let record = CKRecord(
                recordType: CKRecordType.enduranceTemplate,
                recordID: makeRecordID(id: template.id, type: CKRecordType.enduranceTemplate)
            )
            do {
                record[CKFields.payload] = try encodePayload(template) as CKRecordValue
                record[CKFields.updatedAt] = (template.updatedAt ?? Date()) as CKRecordValue
                if let etag = template.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode endurance template failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudWeeklyTemplateStore: WeeklyTemplateStore {
    func loadTemplates() -> [WeeklyTemplate] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [WeeklyTemplate] = []

        let query = CKQuery(recordType: CKRecordType.weeklyTemplate, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load weekly templates error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: WeeklyTemplate = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode weekly template failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ templates: [WeeklyTemplate]) {
        let records: [CKRecord] = templates.compactMap { template in
            let record = CKRecord(recordType: CKRecordType.weeklyTemplate, recordID: makeRecordID(id: template.id, type: CKRecordType.weeklyTemplate))
            do {
                record[CKFields.payload] = try encodePayload(template) as CKRecordValue
                record[CKFields.updatedAt] = (template.updatedAt ?? Date()) as CKRecordValue
                if let etag = template.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode weekly template failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudUnattachedRunStore: UnattachedRunStore {
    func loadRuns() -> [UnattachedRun] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [UnattachedRun] = []

        let query = CKQuery(recordType: CKRecordType.unattachedRun, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load unattached runs error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: UnattachedRun = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode unattached run failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ runs: [UnattachedRun]) {
        let records: [CKRecord] = runs.compactMap { run in
            let record = CKRecord(recordType: CKRecordType.unattachedRun, recordID: makeRecordID(id: run.id, type: CKRecordType.unattachedRun))
            do {
                record[CKFields.payload] = try encodePayload(run) as CKRecordValue
                record[CKFields.updatedAt] = (run.updatedAt ?? Date()) as CKRecordValue
                if let etag = run.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode unattached run failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudImportedHealthWorkoutReferenceStore: ImportedHealthWorkoutReferenceStore {
    func loadReferences() -> [ImportedHealthWorkoutReference] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [ImportedHealthWorkoutReference] = []

        let query = CKQuery(recordType: CKRecordType.importedHealthWorkout, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load imported HealthKit refs error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: ImportedHealthWorkoutReference = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode imported HealthKit ref failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ references: [ImportedHealthWorkoutReference]) {
        let records: [CKRecord] = references.compactMap { reference in
            let record = CKRecord(
                recordType: CKRecordType.importedHealthWorkout,
                recordID: makeRecordID(id: reference.id, type: CKRecordType.importedHealthWorkout)
            )
            do {
                record[CKFields.payload] = try encodePayload(reference) as CKRecordValue
                record[CKFields.updatedAt] = (reference.updatedAt ?? Date()) as CKRecordValue
                if let etag = reference.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode imported HealthKit ref failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudPeriodizedBlockStore: PeriodizedBlockStore {
    func loadBlocks() -> [PeriodizedBlockTemplate] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [PeriodizedBlockTemplate] = []

        let query = CKQuery(recordType: CKRecordType.periodizedBlock, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load periodized blocks error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: PeriodizedBlockTemplate = try decodePayload(data)
                    decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
                    decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
                    return decoded
                } catch {
                    print("Decode periodized block failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ blocks: [PeriodizedBlockTemplate]) {
        let records: [CKRecord] = blocks.compactMap { block in
            let record = CKRecord(
                recordType: CKRecordType.periodizedBlock,
                recordID: makeRecordID(id: block.id, type: CKRecordType.periodizedBlock)
            )
            do {
                record[CKFields.payload] = try encodePayload(block) as CKRecordValue
                record[CKFields.updatedAt] = (block.updatedAt ?? Date()) as CKRecordValue
                if let etag = block.etag { record[CKFields.etag] = etag as CKRecordValue }
                return record
            } catch {
                print("Encode periodized block failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudWeekPlanStore: WeekPlanStore {
    private let dateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    func loadWeek(start: Date) -> WeekPlan? {
        let recordID = makeRecordID(name: dateFormatter.string(from: start), type: CKRecordType.weekPlan)
        let semaphore = DispatchSemaphore(value: 0)
        var result: WeekPlan?

        CKConfig.database.fetch(withRecordID: recordID) { record, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                return
            }
            guard let record, error == nil else {
                if let error = error {
                    print("Cloud load week error: \(error)")
                }
                return
            }
            guard let data = record[CKFields.payload] as? Data else { return }
            do {
                var migrated = try WeekPlanPersistence.decode(data)
                migrated.updatedAt = record[CKFields.updatedAt] as? Date ?? migrated.updatedAt
                migrated.etag = record[CKFields.etag] as? String ?? migrated.etag
                var legacy = WeekPlanMapper.weekPlan(from: migrated)
                legacy.updatedAt = migrated.updatedAt
                legacy.etag = migrated.etag
                result = legacy
            } catch {
                print("Decode week failed: \(error)")
            }
        }
        semaphore.wait()
        return result
    }

    func save(_ week: WeekPlan, start: Date) {
        let recordID = makeRecordID(name: dateFormatter.string(from: start), type: CKRecordType.weekPlan)
        let record = CKRecord(recordType: CKRecordType.weekPlan, recordID: recordID)
        do {
            var migrated = WeekPlanMapper.migratedWeekPlan(from: week)
            migrated.updatedAt = week.updatedAt ?? Date()
            migrated.etag = week.etag
            record[CKFields.payload] = try encodePayload(migrated) as CKRecordValue
            record[CKFields.updatedAt] = (migrated.updatedAt ?? Date()) as CKRecordValue
            if let etag = migrated.etag { record[CKFields.etag] = etag as CKRecordValue }
            modify(records: [record])
        } catch {
            print("Encode week failed: \(error)")
        }
    }

    func fileURL(for start: Date) -> URL {
        // Not used for cloud store
        return StoragePaths.file("weekplan-\(dateFormatter.string(from: start)).json")
    }
}

// MARK: - Common modify operation

/// Coalesces CloudKit writes so rapid local saves (e.g. strength keystrokes) do not
/// enqueue unbounded `CKModifyRecordsOperation`s, each holding a full JSON payload.
private final class CloudKitModifyQueue {
    static let shared = CloudKitModifyQueue()

    private let lock = NSLock()
    private var pendingByRecordName: [String: CKRecord] = [:]
    private var inFlight = false

    func enqueue(_ records: [CKRecord]) {
        guard !records.isEmpty else { return }
        lock.lock()
        for record in records {
            pendingByRecordName[record.recordID.recordName] = record
        }
        let shouldStart = !inFlight
        if shouldStart { inFlight = true }
        lock.unlock()
        if shouldStart {
            flush()
        }
    }

    private func flush() {
        lock.lock()
        let batch = Array(pendingByRecordName.values)
        pendingByRecordName.removeAll(keepingCapacity: true)
        if batch.isEmpty {
            inFlight = false
            lock.unlock()
            return
        }
        lock.unlock()

        let op = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        op.qualityOfService = .utility
        op.modifyRecordsResultBlock = { [weak self] result in
            if case .failure(let error) = result {
                print("❌ Cloud modify records error: \(error)")
            }
            guard let self else { return }
            self.lock.lock()
            let hasPending = !self.pendingByRecordName.isEmpty
            if !hasPending {
                self.inFlight = false
            }
            self.lock.unlock()
            if hasPending {
                self.flush()
            }
        }
        CKConfig.database.add(op)
    }
}

private func modify(records: [CKRecord]) {
    CloudKitModifyQueue.shared.enqueue(records)
}

// MARK: - Reflection / physical-issue cloud stores

private enum CloudJSONArrayStore {
    static func load<T: Decodable>(
        _ type: T.Type,
        recordType: String,
        applyMeta: @escaping (inout T, CKRecord) -> Void
    ) -> [T] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [T] = []
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        CKConfig.database.perform(query, inZoneWith: nil) { records, error in
            defer { semaphore.signal() }
            if let ckError = error as? CKError,
               ckError.code == .unknownItem || ckError.code == .invalidArguments {
                result = []
                return
            }
            guard let records, error == nil else {
                print("Cloud load \(recordType) error: \(String(describing: error))")
                return
            }
            result = records.compactMap { record in
                guard let data = record[CKFields.payload] as? Data else { return nil }
                do {
                    var decoded: T = try decodePayload(data)
                    applyMeta(&decoded, record)
                    return decoded
                } catch {
                    print("Decode \(recordType) failed: \(error)")
                    return nil
                }
            }
        }
        semaphore.wait()
        return result
    }

    static func save<T: Encodable>(
        _ items: [T],
        recordType: String,
        id: (T) -> UUID,
        updatedAt: (T) -> Date?,
        etag: (T) -> String?
    ) {
        let records: [CKRecord] = items.compactMap { item in
            let record = CKRecord(
                recordType: recordType,
                recordID: makeRecordID(id: id(item), type: recordType)
            )
            do {
                record[CKFields.payload] = try encodePayload(item) as CKRecordValue
                record[CKFields.updatedAt] = (updatedAt(item) ?? Date()) as CKRecordValue
                if let tag = etag(item) { record[CKFields.etag] = tag as CKRecordValue }
                return record
            } catch {
                print("Encode \(recordType) failed: \(error)")
                return nil
            }
        }
        modify(records: records)
    }
}

struct CloudActivityReflectionStore: ActivityReflectionStore {
    func load() -> [ActivityReflection] {
        CloudJSONArrayStore.load(ActivityReflection.self, recordType: CKRecordType.activityReflection) { decoded, record in
            decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
            decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
        }
    }
    func save(_ items: [ActivityReflection]) {
        CloudJSONArrayStore.save(items, recordType: CKRecordType.activityReflection, id: \.id, updatedAt: \.updatedAt, etag: \.etag)
    }
}

struct CloudWeeklyReflectionStore: WeeklyReflectionStore {
    func load() -> [WeeklyReflection] {
        CloudJSONArrayStore.load(WeeklyReflection.self, recordType: CKRecordType.weeklyReflection) { decoded, record in
            decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
            decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
        }
    }
    func save(_ items: [WeeklyReflection]) {
        CloudJSONArrayStore.save(items, recordType: CKRecordType.weeklyReflection, id: \.id, updatedAt: \.updatedAt, etag: \.etag)
    }
}

struct CloudPhysicalIssueStore: PhysicalIssueStore {
    func load() -> [PhysicalIssue] {
        CloudJSONArrayStore.load(PhysicalIssue.self, recordType: CKRecordType.physicalIssue) { decoded, record in
            decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
            decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
        }
    }
    func save(_ items: [PhysicalIssue]) {
        CloudJSONArrayStore.save(items, recordType: CKRecordType.physicalIssue, id: \.id, updatedAt: \.updatedAt, etag: \.etag)
    }
}

struct CloudActivityIssueReportStore: ActivityIssueReportStore {
    func load() -> [ActivityIssueReport] {
        CloudJSONArrayStore.load(ActivityIssueReport.self, recordType: CKRecordType.activityIssueReport) { decoded, record in
            decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
            decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
        }
    }
    func save(_ items: [ActivityIssueReport]) {
        CloudJSONArrayStore.save(items, recordType: CKRecordType.activityIssueReport, id: \.id, updatedAt: \.updatedAt, etag: \.etag)
    }
}

struct CloudWeeklyIssueReviewStore: WeeklyIssueReviewStore {
    func load() -> [WeeklyIssueReview] {
        CloudJSONArrayStore.load(WeeklyIssueReview.self, recordType: CKRecordType.weeklyIssueReview) { decoded, record in
            decoded.updatedAt = record[CKFields.updatedAt] as? Date ?? decoded.updatedAt
            decoded.etag = record[CKFields.etag] as? String ?? decoded.etag
        }
    }
    func save(_ items: [WeeklyIssueReview]) {
        CloudJSONArrayStore.save(items, recordType: CKRecordType.weeklyIssueReview, id: \.id, updatedAt: \.updatedAt, etag: \.etag)
    }
}
