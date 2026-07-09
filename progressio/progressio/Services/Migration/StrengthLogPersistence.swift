import Foundation

enum StrengthLogPersistence {

    static func strengthLogURL(for sessionID: UUID, fileManager: FileManager = .default) -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("\(LegacyDataDecoder.strengthLogPrefix)\(sessionID.uuidString).json")
    }

    static func load(from url: URL) -> StrengthLogState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try decode(from: url)
        } catch {
            print("Failed to load strength log at \(url): \(error)")
            return nil
        }
    }

    static func decode(from url: URL, fileManager: FileManager = .default) throws -> StrengthLogState {
        let data = try Data(contentsOf: url)
        return try decode(data, fileModificationDate: fileModificationDate(for: url, fileManager: fileManager))
    }

    static func decode(_ data: Data, fileModificationDate: Date? = nil) throws -> StrengthLogState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var state = try decoder.decode(StrengthLogState.self, from: data)
        MetadataStamping.stamp(&state, fallbackTimestamp: fileModificationDate ?? Date())
        return state
    }

    static func save(_ state: StrengthLogState, to url: URL) throws {
        var stamped = state
        MetadataStamping.stamp(&stamped, fallbackTimestamp: Date())
        stamped.updatedAt = Date()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(stamped)
        try data.write(to: url, options: .atomic)
    }

    static func jsonNeedsMetadataMigration(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["schemaVersion"] == nil
    }

    static func fileModificationDate(for url: URL, fileManager: FileManager = .default) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
}
