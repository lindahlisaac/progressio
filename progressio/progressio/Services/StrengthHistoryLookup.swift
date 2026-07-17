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
        let neededKeys = Set(currentLiftNames.map(normalizeLiftName).filter { !$0.isEmpty })
        let currentTitleKey = normalizeSessionTitle(current.title)
        let currentTemplate = current.templateName?.trimmingCharacters(in: .whitespacesAndNewlines)

        var priorByLift: [String: PriorLiftPerformance] = [:]
        var similarSession: PriorStrengthSession?
        var bestScore = 0

        let weekStarts = WeekPlanFileIndex.allWeekStarts().prefix(lookbackWeeks)
        for weekStart in weekStarts {
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
                          isCompletedStrength(workout),
                          let snapshot = workout.completedValues.completedStrengthRoutineSnapshot
                    else { continue }

                    let sessionDate = workout.completedValues.completedAt ?? day.date
                    let lifts = priorLifts(
                        from: snapshot,
                        sessionTitle: workout.title,
                        date: sessionDate,
                        workoutID: workout.id
                    )
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
                        neededKeys: neededKeys
                    )
                    if score > bestScore {
                        bestScore = score
                        similarSession = PriorStrengthSession(
                            id: workout.id,
                            title: workout.title,
                            date: sessionDate,
                            matchLabel: matchLabel(
                                workout: workout,
                                currentTemplate: currentTemplate,
                                currentTitleKey: currentTitleKey,
                                score: score
                            ),
                            lifts: lifts
                        )
                    }

                    if bestScore > 0, neededKeys.isSubset(of: Set(priorByLift.keys)) {
                        return StrengthComparisonResult(similarSession: similarSession, priorByLift: priorByLift)
                    }
                }
            }
        }

        if bestScore <= 0 {
            similarSession = nil
        }
        return StrengthComparisonResult(similarSession: similarSession, priorByLift: priorByLift)
    }

    private static func isCompletedStrength(_ workout: Workout) -> Bool {
        switch workout.status {
        case .completed, .partiallyCompleted:
            return true
        case .planned, .skipped, .imported:
            return false
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

    private static func sessionScore(
        workout: Workout,
        lifts: [PriorLiftPerformance],
        currentTitleKey: String,
        currentTemplate: String?,
        neededKeys: Set<String>
    ) -> Int {
        var score = 0
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

    private static func matchLabel(
        workout: Workout,
        currentTemplate: String?,
        currentTitleKey: String,
        score: Int
    ) -> String {
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
