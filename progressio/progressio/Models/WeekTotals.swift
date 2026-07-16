import Foundation

/// Per-modality completed/planned totals for the week planner summary.
struct WeekModalityTotal: Identifiable, Equatable {
    let activityType: ActivityType
    var plannedAmount: Double
    var completedAmount: Double
    var unitLabel: String

    var id: String { activityType.rawValue }

    var displayLine: String {
        let planned = format(plannedAmount)
        let completed = format(completedAmount)
        return "\(activityType.rawValue): \(completed) / \(planned) \(unitLabel)"
    }

    private func format(_ value: Double) -> String {
        if activityType == .strength {
            return String(Int(value.rounded()))
        }
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

enum WeekTotals {

    /// Builds one row per activity type present among active (non-deleted) workouts.
    static func modalityTotals(for week: WeekPlan) -> [WeekModalityTotal] {
        let workouts = week.days.flatMap(\.activeWorkouts)
        guard !workouts.isEmpty else { return [] }

        let order = ActivityType.plannerAddTypes
        var results: [WeekModalityTotal] = []

        for activity in order {
            let matching = workouts.filter { $0.activityType == activity }
            guard !matching.isEmpty else { continue }

            if activity == .strength {
                let planned = Double(matching.count)
                let completed = Double(matching.filter { $0.status == .completed || $0.status == .partiallyCompleted }.count)
                results.append(
                    WeekModalityTotal(
                        activityType: activity,
                        plannedAmount: planned,
                        completedAmount: completed,
                        unitLabel: matching.count == 1 ? "session" : "sessions"
                    )
                )
                continue
            }

            let useDuration = activity == .bike && matching.allSatisfy {
                miles(from: $0.plannedDistance) == 0 && miles(from: $0.actualDistance) == 0
            }

            var planned = 0.0
            var completed = 0.0
            for workout in matching {
                if useDuration {
                    planned += durationHours(from: workout.plannedDuration)
                    if workout.status == .completed || workout.status == .partiallyCompleted {
                        let actual = durationHours(from: workout.actualDuration)
                        completed += actual > 0 ? actual : durationHours(from: workout.plannedDuration)
                    }
                } else {
                    planned += miles(from: workout.plannedDistance)
                    if workout.status == .completed || workout.status == .partiallyCompleted {
                        let actual = miles(from: workout.actualDistance)
                        completed += actual > 0 ? actual : miles(from: workout.plannedDistance)
                    }
                }
            }

            results.append(
                WeekModalityTotal(
                    activityType: activity,
                    plannedAmount: planned,
                    completedAmount: completed,
                    unitLabel: useDuration ? "hr" : "mi"
                )
            )
        }

        return results
    }

    static func miles(from distanceString: String) -> Double {
        guard !distanceString.isEmpty else { return 0 }
        let filtered = distanceString.filter { "0123456789.".contains($0) }
        return Double(filtered) ?? 0
    }

    /// Parses `HH:MM:SS` / `MM:SS` / seconds-ish strings into hours.
    static func durationHours(from durationString: String) -> Double {
        let trimmed = durationString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let parts = trimmed.split(separator: ":").compactMap { Double($0) }
        if parts.count == 3 {
            return (parts[0] * 3600 + parts[1] * 60 + parts[2]) / 3600
        }
        if parts.count == 2 {
            return (parts[0] * 60 + parts[1]) / 3600
        }
        if let seconds = Double(trimmed.filter { "0123456789.".contains($0) }) {
            // Heuristic: values >= 100 treated as seconds; smaller as minutes.
            if seconds >= 100 {
                return seconds / 3600
            }
            return seconds / 60
        }
        return 0
    }
}
