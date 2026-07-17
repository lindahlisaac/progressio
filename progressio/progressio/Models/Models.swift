import SwiftUI

enum SessionKind: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength"
    case run = "Run"
    case cycle = "Cycle"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .run: return "figure.run"
        case .cycle: return "bicycle"
        }
    }
}

enum PlanStatus: String, CaseIterable, Codable {
    case planned = "Planned"
    case completed = "Completed"
    case unplanned = "Unplanned"
    case skipped = "Skipped"

    var tint: Color {
        switch self {
        case .planned: return .blue.opacity(0.8)
        case .completed: return .green.opacity(0.85)
        case .unplanned: return .orange.opacity(0.85)
        case .skipped: return .gray.opacity(0.8)
        }
    }
}

enum TemplateCategory: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength"
    case endurance = "Endurance"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .endurance: return "figure.run"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case Self.strength.rawValue:
            self = .strength
        case Self.endurance.rawValue, "Run":
            // Legacy templates stored non-strength as "Run".
            self = .endurance
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown TemplateCategory: \(raw)"
            )
        }
    }
}

enum RunCategory: String, CaseIterable, Codable, Identifiable {
    case easy = "Easy"
    case recovery = "Recovery"
    case tempo = "Tempo"
    case threshold = "Threshold"
    case vo2 = "VO2"
    case longRun = "Long Run"
    case race = "Race"

    var id: String { rawValue }
}

struct RunDetailData: Codable, Equatable {
    var title: String
    var notes: String
    var distance: String
    var duration: String
    var averageHR: String
    var category: RunCategory?
    var hkWorkoutUUID: String?
    var elevationGain: String?
    var eventDate: Date?
    var updatedAt: Date?
    var etag: String?
}

struct SetLog: Identifiable, Codable, Equatable {
    let id: UUID
    var weight: String
    var reps: String
    var repHint: String
    
    init(id: UUID = UUID(), weight: String = "", reps: String = "", repHint: String = "") {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.repHint = repHint
    }
}

struct ExerciseLog: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sets: [SetLog]
    var rpe: String
    
    init(id: UUID = UUID(), name: String, sets: [SetLog], rpe: String = "") {
        self.id = id
        self.name = name
        self.sets = sets
        self.rpe = rpe
    }
}

struct StrengthLogState: Codable {
    var sessionID: UUID
    var exercises: [ExerciseLog]
    var isCompleted: Bool
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        sessionID: UUID,
        exercises: [ExerciseLog],
        isCompleted: Bool = false,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.sessionID = sessionID
        self.exercises = exercises
        self.isCompleted = isCompleted
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        exercises = try container.decode([ExerciseLog].self, forKey: .exercises)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct PlannedSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var kind: SessionKind
    var status: PlanStatus
    var note: String?
    var templateName: String?
    var runDetail: RunDetailData?
    var actualRun: RunDetailData?
    var strengthLog: StrengthLogState?
    var updatedAt: Date?
    var etag: String?

    init(id: UUID = UUID(), title: String, kind: SessionKind, status: PlanStatus = .planned, note: String? = nil, templateName: String? = nil, runDetail: RunDetailData? = nil, strengthLog: StrengthLogState? = nil, updatedAt: Date? = Date(), etag: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.status = status
        self.note = note
        self.templateName = templateName
        self.runDetail = runDetail
        self.strengthLog = strengthLog
        self.updatedAt = updatedAt
        self.etag = etag
    }
}

struct DayPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    var workouts: [Workout]
    var updatedAt: Date?
    var etag: String?

    init(id: UUID = UUID(), date: Date, workouts: [Workout] = [], updatedAt: Date? = Date(), etag: String? = nil) {
        self.id = id
        self.date = date
        self.workouts = workouts
        self.updatedAt = updatedAt
        self.etag = etag
    }

    var activeWorkouts: [Workout] {
        workouts
            .enumerated()
            .filter { !$0.element.metadata.isDeleted }
            .sorted { lhs, rhs in
                if lhs.element.timePeriod != rhs.element.timePeriod {
                    return lhs.element.timePeriod.sortIndex < rhs.element.timePeriod.sortIndex
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        let decodedDate = date
        if let decodedWorkouts = try container.decodeIfPresent([Workout].self, forKey: .workouts) {
            workouts = decodedWorkouts
        } else {
            let sessions = try container.decode([PlannedSession].self, forKey: .sessions)
            workouts = sessions.map { LegacySessionMapper.workout(from: $0, plannedDate: decodedDate) }
        }
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(workouts, forKey: .workouts)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(etag, forKey: .etag)
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, workouts, sessions, updatedAt, etag
    }
}

struct WeekPlan: Codable {
    let startOfWeek: Date
    var days: [DayPlan]
    /// Display name when this week was applied from a periodized block (e.g. "Peak").
    var appliedPeriodizedWeekName: String?
    var appliedPeriodizedBlockId: UUID?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        startOfWeek: Date,
        days: [DayPlan],
        appliedPeriodizedWeekName: String? = nil,
        appliedPeriodizedBlockId: UUID? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
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
        startOfWeek = try container.decode(Date.self, forKey: .startOfWeek)
        days = try container.decode([DayPlan].self, forKey: .days)
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

struct WeeklyTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var note: String?
    var days: [DayTemplate]
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        name: String,
        note: String? = nil,
        days: [DayTemplate],
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.days = days
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
        note = try container.decodeIfPresent(String.self, forKey: .note)
        days = try container.decode([DayTemplate].self, forKey: .days)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct DayTemplate: Identifiable, Codable {
    let id: UUID
    var weekday: Int // 1 = Sunday ... 7 = Saturday
    var workoutEntries: [WeeklyTemplateWorkoutEntry]
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        weekday: Int,
        workoutEntries: [WeeklyTemplateWorkoutEntry] = [],
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.weekday = weekday
        self.workoutEntries = workoutEntries
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weekday = try container.decode(Int.self, forKey: .weekday)
        if let entries = try container.decodeIfPresent([WeeklyTemplateWorkoutEntry].self, forKey: .workoutEntries) {
            workoutEntries = entries
        } else if let sessions = try container.decodeIfPresent([PlannedSession].self, forKey: .sessions) {
            workoutEntries = sessions.map(WeeklyTemplateWorkoutEntry.from(session:))
        } else {
            workoutEntries = []
        }
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(weekday, forKey: .weekday)
        try container.encode(workoutEntries, forKey: .workoutEntries)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, weekday, workoutEntries, sessions
        case schemaVersion, createdAt, updatedAt, isDeleted, deletedAt
    }
}

struct StrengthTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var exercises: [StrengthExercise]
    var note: String?
    var runCategory: RunCategory?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        exercises: [StrengthExercise],
        note: String? = nil,
        runCategory: RunCategory? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.exercises = exercises
        self.note = note
        self.runCategory = runCategory
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
        category = try container.decode(TemplateCategory.self, forKey: .category)
        exercises = try container.decode([StrengthExercise].self, forKey: .exercises)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        runCategory = try container.decodeIfPresent(RunCategory.self, forKey: .runCategory)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct StrengthExercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var sets: [StrengthSetTemplate]

    init(id: UUID = UUID(), name: String, sets: [StrengthSetTemplate]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct StrengthSetTemplate: Identifiable, Codable {
    let id: UUID
    var targetReps: Int
    var targetWeight: Double
    var targetRPE: Double?
    var repRange: String?

    init(id: UUID = UUID(), targetReps: Int, targetWeight: Double, targetRPE: Double? = nil, repRange: String? = nil) {
        self.id = id
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetRPE = targetRPE
        self.repRange = repRange
    }
}

struct NewExerciseInput: Identifiable {
    let id = UUID()
    var name: String
    var setsCount: Int
    var repRange: String
    var createdAt: Date = Date()
}

struct UnattachedRun: Identifiable, Codable, Equatable {
    let id: UUID
    var detail: RunDetailData
    var date: Date
    var source: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        detail: RunDetailData,
        date: Date,
        source: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.detail = detail
        self.date = date
        self.source = source
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
        detail = try container.decode(RunDetailData.self, forKey: .detail)
        date = try container.decode(Date.self, forKey: .date)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try container.decodeIfPresent(String.self, forKey: .etag)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}



