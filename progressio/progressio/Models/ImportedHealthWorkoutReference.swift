import Foundation

/// Tracks HealthKit UUIDs already imported so re-import is idempotent.
struct ImportedHealthWorkoutReference: Identifiable, Codable, Equatable {
    let id: UUID
    var healthKitUUID: String
    var importedAt: Date
    var linkedWorkoutId: UUID?
    var activityType: ActivityType
    var workoutStartDate: Date?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        healthKitUUID: String,
        importedAt: Date = Date(),
        linkedWorkoutId: UUID? = nil,
        activityType: ActivityType = .roadRun,
        workoutStartDate: Date? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.healthKitUUID = healthKitUUID
        self.importedAt = importedAt
        self.linkedWorkoutId = linkedWorkoutId
        self.activityType = activityType
        self.workoutStartDate = workoutStartDate
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        healthKitUUID = try container.decode(String.self, forKey: .healthKitUUID)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        linkedWorkoutId = try container.decodeIfPresent(UUID.self, forKey: .linkedWorkoutId)
        activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) ?? .roadRun
        workoutStartDate = try container.decodeIfPresent(Date.self, forKey: .workoutStartDate)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt ?? importedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

/// Pending user decision for a HealthKit import that matches a planned workout.
struct PendingHealthKitMatch: Identifiable, Equatable {
    let id: UUID
    let candidate: HealthKitImportCandidate
    let plannedWorkoutID: UUID
    let dayDate: Date
    let plannedTitle: String

    init(
        id: UUID = UUID(),
        candidate: HealthKitImportCandidate,
        plannedWorkoutID: UUID,
        dayDate: Date,
        plannedTitle: String
    ) {
        self.id = id
        self.candidate = candidate
        self.plannedWorkoutID = plannedWorkoutID
        self.dayDate = dayDate
        self.plannedTitle = plannedTitle
    }
}

/// Normalized import DTO produced by the HealthKit pipeline (precursor to persistence).
struct HealthKitImportCandidate: Equatable, Identifiable {
    var id: String { healthKitUUID }
    let healthKitUUID: String
    let startDate: Date
    let activityType: ActivityType
    let detail: RunDetailData
    let sourceName: String?

    var unattachedRun: UnattachedRun {
        UnattachedRun(detail: detail, date: startDate, source: sourceName)
    }
}
