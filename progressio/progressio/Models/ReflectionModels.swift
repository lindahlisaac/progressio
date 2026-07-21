import Foundation

// MARK: - Week key

enum WeekKey {
    /// Monday `startOfWeek` as `yyyy-MM-dd` (matches weekplan file / CloudKit naming).
    static func string(for startOfWeek: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: startOfWeek)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - Scales / enums

enum SessionFeel: Int, Codable, CaseIterable, Identifiable {
    case awful = 1
    case poor = 2
    case ok = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .awful: return "Awful"
        case .poor: return "Poor"
        case .ok: return "OK"
        case .good: return "Good"
        case .great: return "Great"
        }
    }
}

enum FatigueLevel: Int, Codable, CaseIterable, Identifiable {
    case veryFresh = 1
    case fresh = 2
    case normal = 3
    case fatigued = 4
    case veryFatigued = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .veryFresh: return "Very fresh"
        case .fresh: return "Fresh"
        case .normal: return "Normal"
        case .fatigued: return "Fatigued"
        case .veryFatigued: return "Very fatigued"
        }
    }
}

enum RecoveryLevel: Int, Codable, CaseIterable, Identifiable {
    case poor = 1
    case belowAverage = 2
    case normal = 3
    case good = 4
    case excellent = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .poor: return "Poor"
        case .belowAverage: return "Below average"
        case .normal: return "Normal"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

enum MotivationLevel: Int, Codable, CaseIterable, Identifiable {
    case veryLow = 1
    case low = 2
    case moderate = 3
    case high = 4
    case veryHigh = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .veryLow: return "Very low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very high"
        }
    }
}

enum MoodLevel: Int, Codable, CaseIterable, Identifiable {
    case veryLow = 1
    case low = 2
    case okay = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .veryLow: return "Very low"
        case .low: return "Low"
        case .okay: return "Okay"
        case .good: return "Good"
        case .great: return "Great"
        }
    }
}

enum LifeStressLevel: Int, Codable, CaseIterable, Identifiable {
    case veryLow = 1
    case low = 2
    case moderate = 3
    case high = 4
    case veryHigh = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .veryLow: return "Very low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very high"
        }
    }
}

enum SleepQualityLevel: Int, Codable, CaseIterable, Identifiable {
    case poor = 1
    case belowAverage = 2
    case normal = 3
    case good = 4
    case excellent = 5

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .poor: return "Poor"
        case .belowAverage: return "Below average"
        case .normal: return "Normal"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}

enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case foot = "Foot"
    case ankle = "Ankle"
    case shin = "Shin"
    case calf = "Calf"
    case knee = "Knee"
    case quad = "Quad"
    case hamstring = "Hamstring"
    case hip = "Hip"
    case groin = "Groin"
    case lowerBack = "Lower back"
    case upperBack = "Upper back"
    case shoulder = "Shoulder"
    case elbow = "Elbow"
    case wrist = "Wrist"
    case neck = "Neck"
    case other = "Other"

    var id: String { rawValue }
}

enum BodySide: String, Codable, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
    case notApplicable = "N/A"

    var id: String { rawValue }
}

enum PhysicalIssueStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case resolved = "Resolved"

    var id: String { rawValue }
}

enum DiscomfortTiming: String, Codable, CaseIterable, Identifiable {
    case before = "Before"
    case during = "During"
    case after = "After"
    case nextDay = "Next day"

    var id: String { rawValue }
}

enum DiscomfortTrend: String, Codable, CaseIterable, Identifiable {
    case worsened = "Worsened"
    case stable = "Stable"
    case improved = "Improved"

    var id: String { rawValue }
}

enum WeeklyIssueTrend: String, Codable, CaseIterable, Identifiable {
    case worsened = "Worsened"
    case stable = "Stable"
    case improved = "Improved"
    case resolved = "Resolved"

    var id: String { rawValue }
}

// MARK: - Entities

struct ActivityReflection: Identifiable, Codable, Equatable {
    let id: UUID
    var workoutID: UUID
    var feel: SessionFeel
    /// Session RPE 1–10 (independent of strength per-lift RPE).
    var sessionRPE: Int
    var performanceNotes: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        workoutID: UUID,
        feel: SessionFeel = .ok,
        sessionRPE: Int = 5,
        performanceNotes: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.workoutID = workoutID
        self.feel = feel
        self.sessionRPE = min(10, max(1, sessionRPE))
        self.performanceNotes = performanceNotes
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutID = try c.decode(UUID.self, forKey: .workoutID)
        feel = try c.decodeIfPresent(SessionFeel.self, forKey: .feel) ?? .ok
        sessionRPE = try c.decodeIfPresent(Int.self, forKey: .sessionRPE) ?? 5
        performanceNotes = try c.decodeIfPresent(String.self, forKey: .performanceNotes)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct WeeklyReflection: Identifiable, Codable, Equatable {
    let id: UUID
    /// Monday start-of-week as `yyyy-MM-dd`.
    var weekKey: String
    /// Overall week quality 1–10.
    var weekRating: Int
    var fatigue: FatigueLevel
    var recovery: RecoveryLevel
    var sleepQuality: SleepQualityLevel
    var motivation: MotivationLevel
    var mood: MoodLevel
    var lifeStress: LifeStressLevel
    var whatWentWell: String?
    var nextWeekChanges: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        weekKey: String,
        weekRating: Int = 5,
        fatigue: FatigueLevel = .normal,
        recovery: RecoveryLevel = .normal,
        sleepQuality: SleepQualityLevel = .normal,
        motivation: MotivationLevel = .moderate,
        mood: MoodLevel = .okay,
        lifeStress: LifeStressLevel = .moderate,
        whatWentWell: String? = nil,
        nextWeekChanges: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.weekKey = weekKey
        self.weekRating = min(10, max(1, weekRating))
        self.fatigue = fatigue
        self.recovery = recovery
        self.sleepQuality = sleepQuality
        self.motivation = motivation
        self.mood = mood
        self.lifeStress = lifeStress
        self.whatWentWell = whatWentWell
        self.nextWeekChanges = nextWeekChanges
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        weekKey = try c.decode(String.self, forKey: .weekKey)
        weekRating = try c.decodeIfPresent(Int.self, forKey: .weekRating) ?? 5
        fatigue = try c.decodeIfPresent(FatigueLevel.self, forKey: .fatigue) ?? .normal
        recovery = try c.decodeIfPresent(RecoveryLevel.self, forKey: .recovery) ?? .normal
        sleepQuality = try c.decodeIfPresent(SleepQualityLevel.self, forKey: .sleepQuality) ?? .normal
        motivation = try c.decodeIfPresent(MotivationLevel.self, forKey: .motivation) ?? .moderate
        mood = try c.decodeIfPresent(MoodLevel.self, forKey: .mood) ?? .okay
        lifeStress = try c.decodeIfPresent(LifeStressLevel.self, forKey: .lifeStress) ?? .moderate
        whatWentWell = try c.decodeIfPresent(String.self, forKey: .whatWentWell)
        nextWeekChanges = try c.decodeIfPresent(String.self, forKey: .nextWeekChanges)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct PhysicalIssue: Identifiable, Codable, Equatable {
    let id: UUID
    var bodyArea: BodyArea
    var side: BodySide
    var startedAt: Date
    var status: PhysicalIssueStatus
    var resolvedAt: Date?
    var optionalTitle: String?
    var optionalNotes: String?
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        bodyArea: BodyArea,
        side: BodySide,
        startedAt: Date = Date(),
        status: PhysicalIssueStatus = .active,
        resolvedAt: Date? = nil,
        optionalTitle: String? = nil,
        optionalNotes: String? = nil,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.bodyArea = bodyArea
        self.side = side
        self.startedAt = startedAt
        self.status = status
        self.resolvedAt = resolvedAt
        self.optionalTitle = optionalTitle
        self.optionalNotes = optionalNotes
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bodyArea = try c.decode(BodyArea.self, forKey: .bodyArea)
        side = try c.decode(BodySide.self, forKey: .side)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        status = try c.decodeIfPresent(PhysicalIssueStatus.self, forKey: .status) ?? .active
        resolvedAt = try c.decodeIfPresent(Date.self, forKey: .resolvedAt)
        optionalTitle = try c.decodeIfPresent(String.self, forKey: .optionalTitle)
        optionalNotes = try c.decodeIfPresent(String.self, forKey: .optionalNotes)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt ?? startedAt
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
    }

    var displayName: String {
        if let title = optionalTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if side == .notApplicable {
            return bodyArea.rawValue
        }
        return "\(side.rawValue) \(bodyArea.rawValue)"
    }
}

struct ActivityIssueReport: Identifiable, Codable, Equatable {
    let id: UUID
    var physicalIssueID: UUID
    var workoutID: UUID
    var activityReflectionID: UUID
    /// Pain 1–10.
    var painLevel: Int
    var timing: DiscomfortTiming
    var trendDuringActivity: DiscomfortTrend
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        physicalIssueID: UUID,
        workoutID: UUID,
        activityReflectionID: UUID,
        painLevel: Int = 3,
        timing: DiscomfortTiming = .during,
        trendDuringActivity: DiscomfortTrend = .stable,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.physicalIssueID = physicalIssueID
        self.workoutID = workoutID
        self.activityReflectionID = activityReflectionID
        self.painLevel = min(10, max(1, painLevel))
        self.timing = timing
        self.trendDuringActivity = trendDuringActivity
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        physicalIssueID = try c.decode(UUID.self, forKey: .physicalIssueID)
        workoutID = try c.decode(UUID.self, forKey: .workoutID)
        activityReflectionID = try c.decode(UUID.self, forKey: .activityReflectionID)
        painLevel = try c.decodeIfPresent(Int.self, forKey: .painLevel) ?? 3
        timing = try c.decodeIfPresent(DiscomfortTiming.self, forKey: .timing) ?? .during
        trendDuringActivity = try c.decodeIfPresent(DiscomfortTrend.self, forKey: .trendDuringActivity) ?? .stable
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
    }
}

struct WeeklyIssueReview: Identifiable, Codable, Equatable {
    let id: UUID
    var physicalIssueID: UUID
    var weekKey: String
    var weeklyReflectionID: UUID
    var weeklyTrend: WeeklyIssueTrend
    var resultingStatus: PhysicalIssueStatus
    var schemaVersion: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool
    var deletedAt: Date?
    var etag: String?

    init(
        id: UUID = UUID(),
        physicalIssueID: UUID,
        weekKey: String,
        weeklyReflectionID: UUID,
        weeklyTrend: WeeklyIssueTrend = .stable,
        resultingStatus: PhysicalIssueStatus = .active,
        schemaVersion: Int = WorkoutSchema.currentVersion,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil,
        etag: String? = nil
    ) {
        self.id = id
        self.physicalIssueID = physicalIssueID
        self.weekKey = weekKey
        self.weeklyReflectionID = weeklyReflectionID
        self.weeklyTrend = weeklyTrend
        self.resultingStatus = resultingStatus
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
        self.etag = etag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        physicalIssueID = try c.decode(UUID.self, forKey: .physicalIssueID)
        weekKey = try c.decode(String.self, forKey: .weekKey)
        weeklyReflectionID = try c.decode(UUID.self, forKey: .weeklyReflectionID)
        weeklyTrend = try c.decodeIfPresent(WeeklyIssueTrend.self, forKey: .weeklyTrend) ?? .stable
        resultingStatus = try c.decodeIfPresent(PhysicalIssueStatus.self, forKey: .resultingStatus) ?? .active
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WorkoutSchema.currentVersion
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? updatedAt
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        etag = try c.decodeIfPresent(String.self, forKey: .etag)
    }
}
