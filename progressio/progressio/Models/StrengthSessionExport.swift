import Foundation

/// Session totals shown after completing a strength workout (and while locked).
struct StrengthSessionSummary: Equatable {
    var exerciseCount: Int
    /// Non-skipped sets with weight and/or reps entered.
    var setsLogged: Int
    var setsSkipped: Int
    var totalReps: Int
    /// Sum of weight × reps for sets where both parse; nil when nothing contributed.
    var totalVolume: Double?

    var hasVolume: Bool { totalVolume != nil }

    var volumeDisplay: String {
        guard let totalVolume else { return "—" }
        if totalVolume == totalVolume.rounded() {
            return String(Int(totalVolume.rounded()))
        }
        return String(format: "%.0f", totalVolume)
    }
}

/// Stable JSON envelope for per-session strength export (`formatVersion: 1`).
/// Import of this format is intentionally out of scope (future coach workflows).
struct StrengthSessionExportDocument: Codable, Equatable {
    var formatVersion: Int
    var sessionId: UUID
    var title: String
    var date: Date
    var notes: String?
    var exercises: [ExportedExercise]

    struct ExportedExercise: Codable, Equatable {
        var id: UUID
        var name: String
        var orderIndex: Int
        var exerciseRPE: String?
        var sets: [ExportedSet]
    }

    struct ExportedSet: Codable, Equatable {
        var setNumber: Int
        var weight: String?
        var reps: String?
        var isSkipped: Bool
        var targetReps: Int?
        var repHint: String?
    }
}

enum StrengthSessionExport {

    /// A set "has logged work" when it is not skipped and has weight or reps text.
    static func hasLoggedWork(_ set: SetLog) -> Bool {
        guard !set.isSkipped else { return false }
        let w = set.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = set.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        return !w.isEmpty || !r.isEmpty
    }

    static func summary(from exercises: [ExerciseLog]) -> StrengthSessionSummary {
        var setsLogged = 0
        var setsSkipped = 0
        var totalReps = 0
        var volume: Double = 0
        var volumeContributed = false

        for exercise in exercises {
            for set in exercise.sets {
                if set.isSkipped {
                    setsSkipped += 1
                    continue
                }
                guard hasLoggedWork(set) else { continue }
                setsLogged += 1
                let reps = parseNumber(set.reps).map { Int($0.rounded()) } ?? 0
                totalReps += max(0, reps)
                if let weight = parseNumber(set.weight), let repValue = parseNumber(set.reps) {
                    volume += weight * repValue
                    volumeContributed = true
                }
            }
        }

        return StrengthSessionSummary(
            exerciseCount: exercises.count,
            setsLogged: setsLogged,
            setsSkipped: setsSkipped,
            totalReps: totalReps,
            totalVolume: volumeContributed ? volume : nil
        )
    }

    /// Text export: workout title header, then one line per lift.
    /// Set count = non-skipped sets with logged work; skipped annotated when present.
    static func plainText(title: String, exercises: [ExerciseLog]) -> String {
        let header = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ActivityType.strength.defaultTitle
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines: [String] = [header, ""]
        for exercise in exercises {
            let logged = exercise.sets.filter(hasLoggedWork).count
            let skipped = exercise.sets.filter(\.isSkipped).count
            let setWord = logged == 1 ? "set" : "sets"
            var line = "\(exercise.name) – \(logged) \(setWord)"
            if skipped > 0 {
                line += " (\(skipped) skipped)"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    static func document(
        sessionId: UUID,
        title: String,
        date: Date,
        notes: String?,
        exercises: [ExerciseLog]
    ) -> StrengthSessionExportDocument {
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return StrengthSessionExportDocument(
            formatVersion: 1,
            sessionId: sessionId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ActivityType.strength.defaultTitle
                : title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            notes: (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil,
            exercises: exercises.enumerated().map { index, exercise in
                StrengthSessionExportDocument.ExportedExercise(
                    id: exercise.id,
                    name: exercise.name,
                    orderIndex: index,
                    exerciseRPE: emptyToNil(exercise.rpe),
                    sets: exercise.sets.enumerated().map { setIndex, set in
                        StrengthSessionExportDocument.ExportedSet(
                            setNumber: setIndex + 1,
                            weight: set.isSkipped ? nil : emptyToNil(set.weight),
                            reps: set.isSkipped ? nil : emptyToNil(set.reps),
                            isSkipped: set.isSkipped,
                            targetReps: singleTargetReps(from: set.repHint),
                            repHint: emptyToNil(set.repHint)
                        )
                    }
                )
            }
        )
    }

    static func writeJSONFile(
        sessionId: UUID,
        title: String,
        date: Date,
        notes: String?,
        exercises: [ExerciseLog]
    ) -> URL? {
        let doc = document(
            sessionId: sessionId,
            title: title,
            date: date,
            notes: notes,
            exercises: exercises
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(doc)
            let slug = sessionId.uuidString.lowercased().prefix(8)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("strength-session-\(slug).json")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Single planned rep target when hint is a lone number; ranges stay in `repHint` only.
    private static func singleTargetReps(from hint: String) -> Int? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("-") || trimmed.contains("–") || trimmed.contains("—") { return nil }
        guard let value = Int(trimmed.filter(\.isNumber)), value > 0 else { return nil }
        return value
    }

    private static func parseNumber(_ string: String) -> Double? {
        let filtered = string.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty else { return nil }
        return Double(filtered)
    }
}
