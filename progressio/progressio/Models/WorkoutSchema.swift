import Foundation

/// Current persisted schema version for new domain records (workouts, templates, etc.).
enum WorkoutSchema {
    static let currentVersion = 1
}

/// Shared sync and lifecycle metadata for persisted records.
struct RecordMetadata: Codable, Equatable {
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}
