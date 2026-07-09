import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case roadRun = "Road Run"
    case trailRun = "Trail Run"
    case walk = "Walk"
    case bike = "Bike"
    case strength = "Strength"

    var id: String { rawValue }
}

enum WorkoutStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case completed = "Completed"
    case skipped = "Skipped"
    case imported = "Imported"
    case partiallyCompleted = "Partially Completed"
}

enum WorkoutSource: String, Codable, CaseIterable {
    case manual = "Manual"
    case template = "Template"
    case appleHealth = "Apple Health"
}

enum TimePeriod: String, Codable, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }

    /// Default AM/PM cutoff per docs: AM = midnight–11:59am, PM = noon–11:59pm.
    static func from(date: Date, calendar: Calendar = .current) -> TimePeriod {
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? .am : .pm
    }
}

enum RunType: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy"
    case recovery = "Recovery"
    case tempo = "Tempo"
    case threshold = "Threshold"
    case vo2 = "VO2"
    case longRun = "Long Run"
    case race = "Race"

    var id: String { rawValue }
}

// MARK: - Legacy enum bridges (mapper support only)

extension ActivityType {
    init(sessionKind: SessionKind) {
        switch sessionKind {
        case .strength: self = .strength
        case .run: self = .roadRun
        case .cycle: self = .bike
        }
    }

    var sessionKind: SessionKind {
        switch self {
        case .strength: return .strength
        case .roadRun, .trailRun, .walk: return .run
        case .bike: return .cycle
        }
    }
}

extension WorkoutStatus {
    init(planStatus: PlanStatus) {
        switch planStatus {
        case .planned: self = .planned
        case .completed: self = .completed
        case .skipped: self = .skipped
        case .unplanned: self = .imported
        }
    }

    var planStatus: PlanStatus {
        switch self {
        case .planned: return .planned
        case .completed, .partiallyCompleted: return .completed
        case .skipped: return .skipped
        case .imported: return .unplanned
        }
    }
}

extension RunType {
    init?(runCategory: RunCategory) {
        switch runCategory {
        case .easy: self = .easy
        case .recovery: self = .recovery
        case .tempo: self = .tempo
        case .threshold: self = .threshold
        case .vo2: self = .vo2
        case .race: self = .race
        }
    }

    var runCategory: RunCategory? {
        switch self {
        case .easy: return .easy
        case .recovery: return .recovery
        case .tempo: return .tempo
        case .threshold: return .threshold
        case .vo2: return .vo2
        case .longRun: return nil
        case .race: return .race
        }
    }
}

extension RunCategory {
    init?(runType: RunType) {
        switch runType {
        case .easy: self = .easy
        case .recovery: self = .recovery
        case .tempo: self = .tempo
        case .threshold: self = .threshold
        case .vo2: self = .vo2
        case .race: self = .race
        case .longRun: return nil
        }
    }
}
