import Foundation
import CloudKit

private enum CKConfig {
    static let container = CKContainer.default()
    static let database = CKConfig.container.privateCloudDatabase
}

private enum CKRecordType {
    static let template = "StrengthTemplate"
    static let weeklyTemplate = "WeeklyTemplate"
    static let unattachedRun = "UnattachedRun"
    static let weekPlan = "WeekPlan"
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
                var legacy = WeekPlanMapper.legacyWeekPlan(from: migrated)
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

private func modify(records: [CKRecord]) {
    guard !records.isEmpty else { return }
    for record in records {
        if let data = record[CKFields.payload] as? Data {
            if let json = String(data: data, encoding: .utf8) {
                print("🪵 Cloud save payload \(record.recordType) \(record.recordID.recordName): \(json)")
            } else {
                print("🪵 Cloud save payload \(record.recordType) \(record.recordID.recordName): \(data.count) bytes (non-UTF8)")
            }
        }
    }
    let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
    op.savePolicy = .allKeys
    op.perRecordSaveBlock = { recordID, result in
        switch result {
        case .success:
            print("✅ Cloud saved record \(recordID.recordName)")
        case .failure(let error):
            print("❌ Cloud save failed for \(recordID.recordName): \(error)")
        }
    }
    op.modifyRecordsResultBlock = { result in
        switch result {
        case .success:
            print("✅ Cloud modify batch succeeded (\(records.count) records)")
        case .failure(let error):
            print("❌ Cloud modify records error: \(error)")
        }
    }
    CKConfig.database.add(op)
}
