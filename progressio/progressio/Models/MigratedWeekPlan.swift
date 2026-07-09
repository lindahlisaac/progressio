import Foundation

/// On-disk week plan format after Task 004 (workouts replace planned sessions).
struct MigratedWeekPlan: Codable, Equatable {
    static let formatVersion = 1

    var formatVersion: Int
    let startOfWeek: Date
    var days: [MigratedDayPlan]
    var updatedAt: Date?
    var etag: String?

    init(
        formatVersion: Int = MigratedWeekPlan.formatVersion,
        startOfWeek: Date,
        days: [MigratedDayPlan],
        updatedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.formatVersion = formatVersion
        self.startOfWeek = startOfWeek
        self.days = days
        self.updatedAt = updatedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? MigratedWeekPlan.formatVersion
        startOfWeek = try container.decode(Date.self, forKey: .startOfWeek)
        days = try container.decode([MigratedDayPlan].self, forKey: .days)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
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
