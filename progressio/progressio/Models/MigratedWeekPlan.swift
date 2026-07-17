import Foundation

/// On-disk week plan format after Task 004 (workouts replace planned sessions).
struct MigratedWeekPlan: Codable, Equatable {
    static let formatVersion = 1

    var formatVersion: Int
    let startOfWeek: Date
    var days: [MigratedDayPlan]
    var appliedPeriodizedWeekName: String?
    var appliedPeriodizedBlockId: UUID?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        formatVersion: Int = MigratedWeekPlan.formatVersion,
        startOfWeek: Date,
        days: [MigratedDayPlan],
        appliedPeriodizedWeekName: String? = nil,
        appliedPeriodizedBlockId: UUID? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.formatVersion = formatVersion
        self.startOfWeek = startOfWeek
        self.days = days
        self.appliedPeriodizedWeekName = appliedPeriodizedWeekName
        self.appliedPeriodizedBlockId = appliedPeriodizedBlockId
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? MigratedWeekPlan.formatVersion
        startOfWeek = try container.decode(Date.self, forKey: .startOfWeek)
        days = try container.decode([MigratedDayPlan].self, forKey: .days)
        appliedPeriodizedWeekName = try container.decodeIfPresent(String.self, forKey: .appliedPeriodizedWeekName)
        appliedPeriodizedBlockId = try container.decodeIfPresent(UUID.self, forKey: .appliedPeriodizedBlockId)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct MigratedDayPlan: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    var workouts: [Workout]
    var updatedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        date: Date,
        workouts: [Workout] = [],
        updatedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.date = date
        self.workouts = workouts
        self.updatedAt = updatedAt
        self.etag = etag
    }
}

extension MigratedWeekPlan {
    var isMigratedFormat: Bool {
        formatVersion >= Self.formatVersion
    }
}
