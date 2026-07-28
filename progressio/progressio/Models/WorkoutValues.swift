import Foundation

struct PlannedValues: Codable, Equatable {
    var plannedDistance: String?
    var plannedDuration: String?
    var plannedElevationGain: String?
    var plannedIntensityRPE: String?
    var plannedDescription: String?
    var plannedRoute: String?
    /// StairMaster machine level 1–20 (string for consistency with other metrics).
    var plannedLevel: String?
    var plannedStrengthRoutineSnapshot: StrengthRoutineSnapshot?

    static let empty = PlannedValues()
}

struct CompletedValues: Codable, Equatable {
    var completedDistance: String?
    var completedDuration: String?
    var completedElevationGain: String?
    var completedIntensityRPE: String?
    var completedCalories: String?
    var completedHeartRateAverage: String?
    var completedHeartRateMax: String?
    var completedDescription: String?
    /// StairMaster machine level 1–20.
    var completedLevel: String?
    var completedStrengthRoutineSnapshot: StrengthRoutineSnapshot?
    var completedAt: Date?

    static let empty = CompletedValues()
}

/// Snapshot of a strength routine (planned targets and/or logged sets).
struct StrengthRoutineSnapshot: Codable, Equatable {
    var exercises: [StrengthExerciseSnapshot]
    var completionNotes: String?

    init(exercises: [StrengthExerciseSnapshot] = [], completionNotes: String? = nil) {
        self.exercises = exercises
        self.completionNotes = completionNotes
    }
}

struct StrengthExerciseSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var orderIndex: Int
    var targetSets: [StrengthSetSnapshot]
    var muscleGroup: String?
    var notes: String?
    var exerciseRPE: String?

    init(
        id: UUID = UUID(),
        name: String,
        orderIndex: Int,
        targetSets: [StrengthSetSnapshot] = [],
        muscleGroup: String? = nil,
        notes: String? = nil,
        exerciseRPE: String? = nil
    ) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.muscleGroup = muscleGroup
        self.notes = notes
        self.exerciseRPE = exerciseRPE
    }
}

struct StrengthSetSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    var setNumber: Int
    var targetReps: Int?
    var targetWeight: Double?
    var repHint: String?
    var actualReps: String?
    var actualWeight: String?
    var notes: String?
    /// Explicit skip (distinct from empty / not logged). Absent in older JSON → false.
    var isSkipped: Bool

    init(
        id: UUID = UUID(),
        setNumber: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        repHint: String? = nil,
        actualReps: String? = nil,
        actualWeight: String? = nil,
        notes: String? = nil,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.repHint = repHint
        self.actualReps = actualReps
        self.actualWeight = actualWeight
        self.notes = notes
        self.isSkipped = isSkipped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        setNumber = try container.decode(Int.self, forKey: .setNumber)
        targetReps = try container.decodeIfPresent(Int.self, forKey: .targetReps)
        targetWeight = try container.decodeIfPresent(Double.self, forKey: .targetWeight)
        repHint = try container.decodeIfPresent(String.self, forKey: .repHint)
        actualReps = try container.decodeIfPresent(String.self, forKey: .actualReps)
        actualWeight = try container.decodeIfPresent(String.self, forKey: .actualWeight)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
    }
}
