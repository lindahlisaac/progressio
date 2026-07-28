import Foundation

/// Condensed prior performance for one lift (matched by normalized name).
struct PriorLiftPerformance: Equatable, Identifiable {
    var id: String { normalizedName }
    let name: String
    let normalizedName: String
    let date: Date
    let sessionTitle: String
    let workoutID: UUID
    /// Display pairs in set order: weight × reps
    let sets: [(weight: String, reps: String)]

    var condensedLine: String {
        let parts = sets.compactMap { set -> String? in
            let w = set.weight.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = set.reps.trimmingCharacters(in: .whitespacesAndNewlines)
            if w.isEmpty, r.isEmpty { return nil }
            if w.isEmpty { return "×\(r)" }
            if r.isEmpty { return w }
            return "\(w)×\(r)"
        }
        return parts.isEmpty ? "No logged sets" : parts.joined(separator: ", ")
    }

    static func == (lhs: PriorLiftPerformance, rhs: PriorLiftPerformance) -> Bool {
        lhs.normalizedName == rhs.normalizedName
            && lhs.date == rhs.date
            && lhs.workoutID == rhs.workoutID
            && lhs.condensedLine == rhs.condensedLine
    }
}

/// A prior completed strength session used for “same kind of day” comparison.
struct PriorStrengthSession: Equatable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let matchLabel: String
    let lifts: [PriorLiftPerformance]
}

struct StrengthComparisonResult: Equatable {
    /// Best recent session matching this routine (title / template / lift overlap).
    var similarSession: PriorStrengthSession?
    /// Last logged performance per lift name (normalized key).
    var priorByLift: [String: PriorLiftPerformance]

    static let empty = StrengthComparisonResult(similarSession: nil, priorByLift: [:])
}

/// Local newest-first scan of week files for prior strength performance.
/// Avoids CloudKit; stops early once a similar session and all requested lifts are found.
enum StrengthHistoryLookup {
    static func normalizeLiftName(_ name: String) -> String {
        // Prefer canonical catalog name so "Lat Pull Down" and "Lat Pulldown" match.
        let canonical = LiftCatalog.canonicalName(for: name)
        return LiftCatalog.normalizeKey(canonical)
    }

    static func normalizeSessionTitle(_ title: String) -> String {
        LiftCatalog.normalizeKey(title)
    }

    static func compare(
        current: Workout,
        currentLiftNames: [String],
        currentWeekPlan: WeekPlan,
        calendar: Calendar = .current,
        lookbackWeeks: Int = 52,
        localStore: WeekPlanStore = FileWeekPlanStore()
    ) -> StrengthComparisonResult {
        let excludeID = current.id
        let orderedKeys = currentLiftNames
            .map(normalizeLiftName)
            .filter { !$0.isEmpty }
        let neededKeys = Set(orderedKeys)
        let currentTitleKey = normalizeSessionTitle(current.title)
        let currentTemplate = current.templateName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTemplateID = current.linkedWorkoutTemplateId

        var priorByLift: [String: PriorLiftPerformance] = [:]
        var similarSession: PriorStrengthSession?
        var bestScore = 0
        var bestWasTemplateMatch = false

        // Always include the in-memory current week — it may not be on disk yet.
        var weekStarts = WeekPlanFileIndex.allWeekStarts()
        if !weekStarts.contains(where: { calendar.isDate($0, inSameDayAs: currentWeekPlan.startOfWeek) }) {
            weekStarts.insert(currentWeekPlan.startOfWeek, at: 0)
        }
        for weekStart in weekStarts.prefix(lookbackWeeks) {
            let plan: WeekPlan
            if calendar.isDate(weekStart, inSameDayAs: currentWeekPlan.startOfWeek) {
                plan = currentWeekPlan
            } else if let loaded = localStore.loadWeek(start: weekStart) {
                plan = loaded
            } else {
                continue
            }

            for day in plan.days.sorted(by: { $0.date > $1.date }) {
                for workout in day.activeWorkouts.reversed() {
                    guard workout.id != excludeID,
                          workout.activityType == .strength,
                          let snapshot = workout.completedValues.completedStrengthRoutineSnapshot
                    else { continue }

                    let sessionDate = workout.completedValues.completedAt ?? day.date
                    let lifts = priorLifts(
                        from: snapshot,
                        sessionTitle: workout.title,
                        date: sessionDate,
                        workoutID: workout.id
                    )
                    // Need at least one logged set — status may still be planned while logging.
                    guard !lifts.isEmpty else { continue }

                    for lift in lifts {
                        if neededKeys.contains(lift.normalizedName), priorByLift[lift.normalizedName] == nil {
                            priorByLift[lift.normalizedName] = lift
                        }
                    }

                    let score = sessionScore(
                        workout: workout,
                        lifts: lifts,
                        currentTitleKey: currentTitleKey,
                        currentTemplate: currentTemplate,
                        currentTemplateID: currentTemplateID,
                        neededKeys: neededKeys
                    )
                    let templateMatch = isTemplateMatch(
                        workout: workout,
                        currentTemplate: currentTemplate,
                        currentTemplateID: currentTemplateID
                    )
                    if score > bestScore {
                        bestScore = score
                        bestWasTemplateMatch = templateMatch
                        similarSession = PriorStrengthSession(
                            id: workout.id,
                            title: workout.title,
                            date: sessionDate,
                            matchLabel: matchLabel(
                                workout: workout,
                                currentTemplate: currentTemplate,
                                currentTemplateID: currentTemplateID,
                                currentTitleKey: currentTitleKey,
                                score: score
                            ),
                            lifts: lifts
                        )
                        if templateMatch {
                            fillPriorByLiftOrder(
                                priorByLift: &priorByLift,
                                orderedKeys: orderedKeys,
                                from: lifts
                            )
                        }
                    }

                    if bestScore > 0, neededKeys.isSubset(of: Set(priorByLift.keys)) {
                        return StrengthComparisonResult(similarSession: similarSession, priorByLift: priorByLift)
                    }
                }
            }
        }

        if bestScore <= 0 {
            similarSession = nil
        } else if bestWasTemplateMatch, let similar = similarSession {
            // Ensure order fallback runs even when the best match was found after name fills stalled.
            fillPriorByLiftOrder(
                priorByLift: &priorByLift,
                orderedKeys: orderedKeys,
                from: similar.lifts
            )
        }
        return StrengthComparisonResult(similarSession: similarSession, priorByLift: priorByLift)
    }

    /// Prefer template-linked / same-name sessions; also accept any logged strength with lift overlap.
    private static func sessionScore(
        workout: Workout,
        lifts: [PriorLiftPerformance],
        currentTitleKey: String,
        currentTemplate: String?,
        currentTemplateID: UUID?,
        neededKeys: Set<String>
    ) -> Int {
        var score = 0
        if let currentTemplateID,
           let priorID = workout.linkedWorkoutTemplateId,
           currentTemplateID == priorID {
            score += 150
        }
        if let currentTemplate,
           let priorTemplate = workout.templateName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentTemplate.isEmpty,
           currentTemplate.caseInsensitiveCompare(priorTemplate) == .orderedSame {
            score += 100
        }
        if !currentTitleKey.isEmpty,
           normalizeSessionTitle(workout.title) == currentTitleKey {
            score += 50
        }
        let overlap = Set(lifts.map(\.normalizedName)).intersection(neededKeys).count
        score += overlap * 10
        return score
    }

    private static func isTemplateMatch(
        workout: Workout,
        currentTemplate: String?,
        currentTemplateID: UUID?
    ) -> Bool {
        if let currentTemplateID,
           let priorID = workout.linkedWorkoutTemplateId,
           currentTemplateID == priorID {
            return true
        }
        if let currentTemplate,
           let priorTemplate = workout.templateName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentTemplate.isEmpty,
           currentTemplate.caseInsensitiveCompare(priorTemplate) == .orderedSame {
            return true
        }
        return false
    }

    /// When the same template was remapped to catalog names, align missing lifts by routine order.
    private static func fillPriorByLiftOrder(
        priorByLift: inout [String: PriorLiftPerformance],
        orderedKeys: [String],
        from lifts: [PriorLiftPerformance]
    ) {
        for (index, key) in orderedKeys.enumerated() {
            guard priorByLift[key] == nil, index < lifts.count else { continue }
            let prior = lifts[index]
            priorByLift[key] = PriorLiftPerformance(
                name: prior.name,
                normalizedName: key,
                date: prior.date,
                sessionTitle: prior.sessionTitle,
                workoutID: prior.workoutID,
                sets: prior.sets
            )
        }
    }

    private static func priorLifts(
        from snapshot: StrengthRoutineSnapshot,
        sessionTitle: String,
        date: Date,
        workoutID: UUID
    ) -> [PriorLiftPerformance] {
        snapshot.exercises.sorted { $0.orderIndex < $1.orderIndex }.compactMap { exercise in
            let sets: [(weight: String, reps: String)] = exercise.targetSets
                .sorted { $0.setNumber < $1.setNumber }
                .compactMap { set in
                    if set.isSkipped { return nil }
                    let w = set.actualWeight?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let r = set.actualReps?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if w.isEmpty, r.isEmpty { return nil }
                    return (w, r)
                }
            guard !sets.isEmpty else { return nil }
            let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return PriorLiftPerformance(
                name: name,
                normalizedName: normalizeLiftName(name),
                date: date,
                sessionTitle: sessionTitle,
                workoutID: workoutID,
                sets: sets
            )
        }
    }

    private static func matchLabel(
        workout: Workout,
        currentTemplate: String?,
        currentTemplateID: UUID?,
        currentTitleKey: String,
        score: Int
    ) -> String {
        if let currentTemplateID,
           let priorID = workout.linkedWorkoutTemplateId,
           currentTemplateID == priorID {
            return "Same template"
        }
        if let currentTemplate,
           let priorTemplate = workout.templateName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentTemplate.isEmpty,
           currentTemplate.caseInsensitiveCompare(priorTemplate) == .orderedSame {
            return "Same template"
        }
        if !currentTitleKey.isEmpty,
           normalizeSessionTitle(workout.title) == currentTitleKey {
            return "Same session title"
        }
        if score >= 10 {
            return "Matching lifts"
        }
        return "Recent strength"
    }
}
