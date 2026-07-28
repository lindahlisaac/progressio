import Foundation

/// Reusable blueprint for road run, trail run, walk, bike, and StairMaster workouts.
struct EnduranceTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var activityType: ActivityType
    var runType: RunType?
    var plannedDistance: String?
    var plannedDuration: String?
    var plannedElevationGain: String?
    /// StairMaster machine level 1–20.
    var plannedLevel: String?
    var description: String?
    var intensityRPE: String?
    var route: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        name: String,
        activityType: ActivityType,
        runType: RunType? = nil,
        plannedDistance: String? = nil,
        plannedDuration: String? = nil,
        plannedElevationGain: String? = nil,
        plannedLevel: String? = nil,
        description: String? = nil,
        intensityRPE: String? = nil,
        route: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.activityType = activityType
        self.runType = runType
        self.plannedDistance = plannedDistance
        self.plannedDuration = plannedDuration
        self.plannedElevationGain = plannedElevationGain
        self.plannedLevel = plannedLevel
        self.description = description
        self.intensityRPE = intensityRPE
        self.route = route
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
        name = try container.decode(String.self, forKey: .name)
        let decodedActivity = try container.decode(ActivityType.self, forKey: .activityType)
        activityType = decodedActivity == .strength ? .roadRun : decodedActivity
        runType = try container.decodeIfPresent(RunType.self, forKey: .runType)
        plannedDistance = try container.decodeIfPresent(String.self, forKey: .plannedDistance)
        plannedDuration = try container.decodeIfPresent(String.self, forKey: .plannedDuration)
        plannedElevationGain = try container.decodeIfPresent(String.self, forKey: .plannedElevationGain)
        plannedLevel = try container.decodeIfPresent(String.self, forKey: .plannedLevel)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        intensityRPE = try container.decodeIfPresent(String.self, forKey: .intensityRPE)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }

    static func fromLegacyStrengthTemplate(_ template: StrengthTemplate) -> EnduranceTemplate {
        EnduranceTemplate(
            id: template.id,
            name: template.name,
            activityType: .roadRun,
            runType: template.runCategory.flatMap(RunType.init(runCategory:)),
            plannedDistance: nil,
            plannedDuration: nil,
            plannedElevationGain: nil,
            plannedLevel: nil,
            description: template.note,
            intensityRPE: nil,
            route: nil,
            schemaVersion: template.schemaVersion,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            isDeleted: template.isDeleted,
            deletedAt: template.deletedAt,
            etag: template.etag
        )
    }
}

extension ActivityType {
    static let enduranceTemplateTypes: [ActivityType] = [.roadRun, .trailRun, .walk, .bike, .stairMaster]
}
