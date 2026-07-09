import Foundation

/// Copies template exercise data into independent workout snapshots.
enum TemplateSnapshot {

    static func plannedSnapshot(from template: StrengthTemplate) -> StrengthRoutineSnapshot {
        let exercises = template.exercises.enumerated().map { index, exercise in
            StrengthExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                orderIndex: index,
                targetSets: exercise.sets.enumerated().map { setIndex, set in
                    StrengthSetSnapshot(
                        id: set.id,
                        setNumber: setIndex + 1,
                        targetReps: set.targetReps > 0 ? set.targetReps : nil,
                        targetWeight: set.targetWeight > 0 ? set.targetWeight : nil,
                        repHint: set.repRange.flatMap(emptyToNil) ?? (set.targetReps > 0 ? String(set.targetReps) : nil),
                        actualReps: nil,
                        actualWeight: nil,
                        notes: set.targetRPE.map { String(format: "%.1f", $0) }
                    )
                },
                muscleGroup: nil,
                notes: nil,
                exerciseRPE: exercise.sets.first?.targetRPE.map { String(format: "%.1f", $0) }
            )
        }
        return StrengthRoutineSnapshot(exercises: exercises, completionNotes: template.note)
    }

    static func exerciseLogs(from snapshot: StrengthRoutineSnapshot, preferActuals: Bool = false) -> [ExerciseLog] {
        snapshot.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
            ExerciseLog(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.targetSets.map { set in
                    let weight: String
                    let reps: String
                    if preferActuals, let actualWeight = set.actualWeight, !actualWeight.isEmpty {
                        weight = actualWeight
                    } else if let targetWeight = set.targetWeight, targetWeight > 0 {
                        weight = String(Int(targetWeight))
                    } else {
                        weight = ""
                    }

                    if preferActuals, let actualReps = set.actualReps, !actualReps.isEmpty {
                        reps = actualReps
                    } else {
                        reps = ""
                    }

                    return SetLog(
                        id: set.id,
                        weight: weight,
                        reps: reps,
                        repHint: set.repHint ?? set.targetReps.map(String.init) ?? ""
                    )
                },
                rpe: exercise.exerciseRPE ?? ""
            )
        }
    }

    static func completedSnapshot(from exercises: [ExerciseLog]) -> StrengthRoutineSnapshot {
        let mapped = exercises.enumerated().map { index, exercise in
            StrengthExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                orderIndex: index,
                targetSets: exercise.sets.enumerated().map { setIndex, set in
                    StrengthSetSnapshot(
                        id: set.id,
                        setNumber: setIndex + 1,
                        targetReps: Int(set.repHint.filter(\.isNumber)),
                        targetWeight: parseDouble(from: set.weight),
                        repHint: emptyToNil(set.repHint),
                        actualReps: emptyToNil(set.reps),
                        actualWeight: emptyToNil(set.weight)
                    )
                },
                exerciseRPE: emptyToNil(exercise.rpe)
            )
        }
        return StrengthRoutineSnapshot(exercises: mapped)
    }

    private static func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseDouble(from string: String) -> Double? {
        let filtered = string.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty, let value = Double(filtered) else { return nil }
        return value
    }
}
