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

    var tint: Color {
        switch self {
        case .planned: return .blue.opacity(0.8)
        case .completed: return .green.opacity(0.85)
        case .unplanned: return .orange.opacity(0.85)
        }
    }
}

enum TemplateCategory: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength"
    case run = "Run"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .run: return "figure.run"
        }
    }
}

enum RunCategory: String, CaseIterable, Codable, Identifiable {
    case easy = "Easy"
    case recovery = "Recovery"
    case tempo = "Tempo"
    case threshold = "Threshold"
    case vo2 = "VO2"
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

    init(sessionID: UUID, exercises: [ExerciseLog], isCompleted: Bool = false) {
        self.sessionID = sessionID
        self.exercises = exercises
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        exercises = try container.decode([ExerciseLog].self, forKey: .exercises)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
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

    init(id: UUID = UUID(), title: String, kind: SessionKind, status: PlanStatus = .planned, note: String? = nil, templateName: String? = nil, runDetail: RunDetailData? = nil, strengthLog: StrengthLogState? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.status = status
        self.note = note
        self.templateName = templateName
        self.runDetail = runDetail
        self.strengthLog = strengthLog
    }
}

struct DayPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    var sessions: [PlannedSession]

    init(id: UUID = UUID(), date: Date, sessions: [PlannedSession] = []) {
        self.id = id
        self.date = date
        self.sessions = sessions
    }
}

struct WeekPlan: Codable {
    let startOfWeek: Date
    var days: [DayPlan]
}

struct WeeklyTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var note: String?
    var days: [DayTemplate]

    init(id: UUID = UUID(), name: String, note: String? = nil, days: [DayTemplate]) {
        self.id = id
        self.name = name
        self.note = note
        self.days = days
    }
}

struct DayTemplate: Identifiable, Codable {
    let id: UUID
    var weekday: Int // 1 = Sunday ... 7 = Saturday
    var sessions: [PlannedSession]

    init(id: UUID = UUID(), weekday: Int, sessions: [PlannedSession] = []) {
        self.id = id
        self.weekday = weekday
        self.sessions = sessions
    }
}

struct StrengthTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var exercises: [StrengthExercise]
    var note: String?
    var runCategory: RunCategory?

    init(id: UUID = UUID(), name: String, category: TemplateCategory, exercises: [StrengthExercise], note: String? = nil, runCategory: RunCategory? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.exercises = exercises
        self.note = note
        self.runCategory = runCategory
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

    init(id: UUID = UUID(), detail: RunDetailData, date: Date, source: String? = nil) {
        self.id = id
        self.detail = detail
        self.date = date
        self.source = source
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



