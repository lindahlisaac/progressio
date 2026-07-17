import Foundation

/// Multi-week training block template (2–12 weeks).
struct PeriodizedBlockTemplate: Identifiable, Codable {
    static let minWeekCount = 2
    static let maxWeekCount = 12

    let id: UUID
    var name: String
    var weekCount: Int
    var weeks: [PeriodizedBlockWeek]
    var notes: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        name: String,
        weekCount: Int,
        weeks: [PeriodizedBlockWeek]? = nil,
        notes: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.name = name
        let clamped = min(max(weekCount, Self.minWeekCount), Self.maxWeekCount)
        self.weekCount = clamped
        if let weeks, weeks.count == clamped {
            self.weeks = weeks
        } else {
            self.weeks = (0..<clamped).map { PeriodizedBlockWeek.blank(weekIndex: $0) }
        }
        self.notes = notes
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
        let rawCount = try container.decode(Int.self, forKey: .weekCount)
        weekCount = min(max(rawCount, Self.minWeekCount), Self.maxWeekCount)
        weeks = try container.decode([PeriodizedBlockWeek].self, forKey: .weeks)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }

    mutating func resize(to newCount: Int) {
        let clamped = min(max(newCount, Self.minWeekCount), Self.maxWeekCount)
        weekCount = clamped
        if weeks.count < clamped {
            for index in weeks.count..<clamped {
                weeks.append(PeriodizedBlockWeek.blank(weekIndex: index))
            }
        } else if weeks.count > clamped {
            weeks = Array(weeks.prefix(clamped))
        }
        for index in weeks.indices {
            weeks[index].weekIndex = index
            if weeks[index].displayName.hasPrefix("Week ") || weeks[index].displayName.isEmpty {
                // Keep custom names; refresh defaults that still match pattern only when blank.
            }
        }
    }
}

/// One week inside a periodized block — either a weekly-template snapshot or a manual day build.
struct PeriodizedBlockWeek: Identifiable, Codable {
    let id: UUID
    var weekIndex: Int
    var displayName: String
    /// Provenance when built from a weekly template; apply uses `daySnapshots`.
    var linkedWeeklyTemplateId: UUID?
    /// Independent day snapshots (preferred apply source).
    var daySnapshots: [DayTemplate]

    init(
        id: UUID = UUID(),
        weekIndex: Int,
        displayName: String? = nil,
        linkedWeeklyTemplateId: UUID? = nil,
        daySnapshots: [DayTemplate] = []
    ) {
        self.id = id
        self.weekIndex = weekIndex
        self.displayName = displayName ?? Self.defaultName(for: weekIndex)
        self.linkedWeeklyTemplateId = linkedWeeklyTemplateId
        self.daySnapshots = daySnapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weekIndex = try container.decode(Int.self, forKey: .weekIndex)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? Self.defaultName(for: weekIndex)
        linkedWeeklyTemplateId = try container.decodeIfPresent(UUID.self, forKey: .linkedWeeklyTemplateId)
        if let snapshots = try container.decodeIfPresent([DayTemplate].self, forKey: .daySnapshots) {
            daySnapshots = snapshots
        } else if let legacy = try container.decodeIfPresent([DayTemplate].self, forKey: .manuallyConstructedWeek) {
            daySnapshots = legacy
        } else {
            daySnapshots = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(weekIndex, forKey: .weekIndex)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(linkedWeeklyTemplateId, forKey: .linkedWeeklyTemplateId)
        try container.encode(daySnapshots, forKey: .daySnapshots)
    }

    private enum CodingKeys: String, CodingKey {
        case id, weekIndex, displayName, linkedWeeklyTemplateId, daySnapshots, manuallyConstructedWeek
    }

    static func defaultName(for weekIndex: Int) -> String {
        "Week \(weekIndex + 1)"
    }

    static func blank(weekIndex: Int) -> PeriodizedBlockWeek {
        PeriodizedBlockWeek(weekIndex: weekIndex, daySnapshots: blankDays())
    }

    static func blankDays() -> [DayTemplate] {
        // Monday=2 ... Saturday=7, Sunday=1
        let weekdays = [2, 3, 4, 5, 6, 7, 1]
        return weekdays.map { DayTemplate(weekday: $0, workoutEntries: []) }
    }

    /// Snapshot a weekly template into this block week (independent of later template edits).
    mutating func applyWeeklyTemplateSnapshot(_ template: WeeklyTemplate) {
        linkedWeeklyTemplateId = template.id
        daySnapshots = template.days.map { day in
            DayTemplate(
                weekday: day.weekday,
                workoutEntries: day.workoutEntries.map { entry in
                    WeeklyTemplateWorkoutEntry(
                        timePeriod: entry.timePeriod,
                        activityType: entry.activityType,
                        runType: entry.runType,
                        title: entry.title,
                        notes: entry.notes,
                        plannedValues: entry.plannedValues,
                        linkedWorkoutTemplateId: entry.linkedWorkoutTemplateId,
                        templateName: entry.templateName
                    )
                }
            )
        }
    }

    var workoutCount: Int {
        daySnapshots.flatMap(\.workoutEntries).count
    }
}
