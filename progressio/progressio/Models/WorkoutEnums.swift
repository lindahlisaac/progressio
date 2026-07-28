import Foundation
import SwiftUI

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case roadRun = "Road Run"
    case trailRun = "Trail Run"
    case walk = "Walk"
    case bike = "Bike"
    case stairMaster = "StairMaster"
    case strength = "Strength"

    var id: String { rawValue }

    /// Modalities offered in the planner add-workout flow.
    static let plannerAddTypes: [ActivityType] = [.roadRun, .trailRun, .walk, .bike, .stairMaster, .strength]

    var systemImage: String {
        switch self {
        case .roadRun, .trailRun: return "figure.run"
        case .walk: return "figure.walk"
        case .bike: return "bicycle"
        case .stairMaster: return "figure.stair.stepper"
        case .strength: return "dumbbell"
        }
    }

    var defaultTitle: String { rawValue }

    /// Endurance modalities that use distance as a primary planning metric.
    var usesDistanceMetric: Bool {
        switch self {
        case .roadRun, .trailRun, .walk, .bike: return true
        case .stairMaster, .strength: return false
        }
    }

    /// Whether run-type (easy/tempo/…) chips apply.
    var usesRunType: Bool {
        switch self {
        case .roadRun, .trailRun, .walk: return true
        case .bike, .stairMaster, .strength: return false
        }
    }
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

    /// AM before PM in day lists.
    var sortIndex: Int {
        switch self {
        case .am: return 0
        case .pm: return 1
        }
    }

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

    /// Planner intensity chip color.
    var tint: Color { runCategory?.tint ?? .blue }
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
        case .bike, .stairMaster: return .cycle
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
        case .longRun: self = .longRun
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
        case .longRun: return .longRun
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
        case .longRun: self = .longRun
        case .race: self = .race
        }
    }

    /// Planner intensity chip color.
    var tint: Color {
        switch self {
        case .easy, .recovery:
            return .green
        case .tempo:
            return .yellow
        case .threshold:
            return .orange
        case .vo2:
            return .red
        case .race:
            return .purple
        case .longRun:
            return .cyan
        }
    }
}
