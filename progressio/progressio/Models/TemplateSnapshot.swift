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
                        repHint: set.repHint ?? set.targetReps.map(String.init) ?? "",
                        isSkipped: set.isSkipped
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
                        targetWeight: set.isSkipped ? nil : parseDouble(from: set.weight),
                        repHint: emptyToNil(set.repHint),
                        actualReps: set.isSkipped ? nil : emptyToNil(set.reps),
                        actualWeight: set.isSkipped ? nil : emptyToNil(set.weight),
                        isSkipped: set.isSkipped
                    )
                },
                exerciseRPE: emptyToNil(exercise.rpe)
            )
        }
        return StrengthRoutineSnapshot(exercises: mapped)
    }

    /// Midpoint of a rep hint like `8-12`, `8–12`, or a single `10`. Nil when unparseable.
    static func midpointReps(from hint: String) -> Int? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " to ", with: "-", options: .caseInsensitive)
        if let dash = normalized.range(of: "-") {
            let leftDigits = normalized[..<dash.lowerBound].filter(\.isNumber)
            let rightDigits = normalized[dash.upperBound...].filter(\.isNumber)
            if let low = Int(leftDigits), let high = Int(rightDigits), low > 0, high > 0 {
                return max(0, min(99, (low + high) / 2))
            }
        }
        let digits = normalized.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else { return nil }
        return max(0, min(99, value))
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
