import Foundation

struct PlannedValues: Codable, Equatable {
    var plannedDistance: String?
    var plannedDuration: String?
    var plannedElevationGain: String?
    var plannedIntensityRPE: String?
    var plannedDescription: String?
    var plannedRoute: String?
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

    init(
        id: UUID = UUID(),
        setNumber: Int,
        targetReps: Int? = nil,
        targetWeight: Double? = nil,
        repHint: String? = nil,
        actualReps: String? = nil,
        actualWeight: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.repHint = repHint
        self.actualReps = actualReps
        self.actualWeight = actualWeight
        self.notes = notes
    }
}
