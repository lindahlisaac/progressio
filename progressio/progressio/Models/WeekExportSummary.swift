import Foundation

/// Condensed week summary for coach share / screenshot export.
enum WeekExportSummary {
    struct DaySection: Identifiable {
        let id: Date
        let title: String
        let workouts: [WorkoutLine]
    }

    struct WorkoutLine: Identifiable {
        let id: UUID
        let timePeriod: String
        let activityType: String
        let title: String
        let status: String
        let detail: String
        let isSkipped: Bool
    }

    struct Snapshot {
        let weekRangeTitle: String
        let subtitle: String?
        let totals: [WeekModalityTotal]
        let elevationLines: [String]
        let days: [DaySection]
        let plainText: String
    }

    static func make(
        from week: WeekPlan,
        calendar: Calendar = .current,
        periodizedWeekName: String? = nil
    ) -> Snapshot {
        let rangeTitle = weekRangeTitle(for: week, calendar: calendar)
        let totals = WeekTotals.modalityTotals(for: week)
        let elevationLines = elevationSummaryLines(for: week)
        let days = week.days.map { day -> DaySection in
            DaySection(
                id: day.date,
                title: dayTitle(for: day.date),
                workouts: day.activeWorkouts.map(workoutLine(from:))
            )
        }

        let plainText = buildPlainText(
            rangeTitle: rangeTitle,
            subtitle: periodizedWeekName,
            totals: totals,
            elevationLines: elevationLines,
            days: days
        )

        return Snapshot(
            weekRangeTitle: rangeTitle,
            subtitle: periodizedWeekName.flatMap { $0.isEmpty ? nil : $0 },
            totals: totals,
            elevationLines: elevationLines,
            days: days,
            plainText: plainText
        )
    }

    // MARK: - Lines

    private static func workoutLine(from workout: Workout) -> WorkoutLine {
        WorkoutLine(
            id: workout.id,
            timePeriod: workout.timePeriod.rawValue,
            activityType: workout.activityType.rawValue,
            title: workout.title,
            status: workout.status.badgeLabel,
            detail: detailLine(for: workout),
            isSkipped: workout.status == .skipped
        )
    }

    private static func detailLine(for workout: Workout) -> String {
        if workout.activityType == .strength {
            var parts: [String] = []
            if let template = workout.templateName, !template.isEmpty {
                parts.append(template)
            }
            if let note = workout.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                parts.append(truncate(note, limit: 40))
            }
            if workout.status == .skipped, let reason = workout.skipReason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                parts.append("Skip: \(truncate(reason, limit: 40))")
            }
            return parts.joined(separator: " · ")
        }

        var parts: [String] = []
        if let cat = workout.runType?.runCategory {
            parts.append(cat.rawValue)
        }

        let miles = planActualPair(
            planned: workout.plannedDistance,
            actual: workout.actualDistance,
            unit: "mi",
            hasActual: workout.hasCompletedEnduranceDetail
        )
        if !miles.isEmpty { parts.append(miles) }

        let vert = planActualPair(
            planned: workout.plannedElevation,
            actual: workout.actualElevation,
            unit: "ft",
            hasActual: workout.hasCompletedEnduranceDetail
        )
        if !vert.isEmpty { parts.append(vert) }

        let duration = planActualPair(
            planned: workout.plannedDuration,
            actual: workout.actualDuration,
            unit: "",
            hasActual: workout.hasCompletedEnduranceDetail,
            includeUnit: false
        )
        if !duration.isEmpty { parts.append(duration) }

        if workout.status == .skipped, let reason = workout.skipReason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
            parts.append("Skip: \(truncate(reason, limit: 40))")
        }

        return parts.joined(separator: " · ")
    }

    /// Formats "plan → actual unit" or just planned when incomplete.
    private static func planActualPair(
        planned: String,
        actual: String,
        unit: String,
        hasActual: Bool,
        includeUnit: Bool = true
    ) -> String {
        let p = planned.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = actual.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = includeUnit && !unit.isEmpty ? " \(unit)" : ""
        if hasActual, !a.isEmpty, !p.isEmpty {
            return "\(p) → \(a)\(suffix)"
        }
        if hasActual, !a.isEmpty {
            return "\(a)\(suffix)"
        }
        if !p.isEmpty {
            return hasActual ? "\(p) → —\(suffix)" : "\(p)\(suffix)"
        }
        return ""
    }

    // MARK: - Elevation totals

    private static func elevationSummaryLines(for week: WeekPlan) -> [String] {
        let workouts = week.days.flatMap(\.activeWorkouts)
        let enduranceTypes: [ActivityType] = [.roadRun, .trailRun, .walk, .bike]
        var lines: [String] = []
        for activity in enduranceTypes {
            let matching = workouts.filter { $0.activityType == activity }
            guard !matching.isEmpty else { continue }
            var planned = 0.0
            var completed = 0.0
            var anyVert = false
            for workout in matching {
                let p = WeekTotals.miles(from: workout.plannedElevation)
                let a = WeekTotals.miles(from: workout.actualElevation)
                if p > 0 || a > 0 { anyVert = true }
                planned += p
                if workout.status == .completed || workout.status == .partiallyCompleted {
                    completed += a > 0 ? a : p
                }
            }
            guard anyVert else { continue }
            lines.append("\(activity.rawValue) vert: \(formatFeet(completed)) / \(formatFeet(planned)) ft")
        }
        return lines
    }

    private static func formatFeet(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%.0f", value)
    }

    // MARK: - Plain text

    private static func buildPlainText(
        rangeTitle: String,
        subtitle: String?,
        totals: [WeekModalityTotal],
        elevationLines: [String],
        days: [DaySection]
    ) -> String {
        var lines: [String] = []
        lines.append(rangeTitle)
        if let subtitle, !subtitle.isEmpty {
            lines.append(subtitle)
        }
        lines.append("")
        lines.append("WEEKLY TOTALS")
        if totals.isEmpty {
            lines.append("No workouts this week")
        } else {
            for total in totals {
                lines.append(total.displayLine)
            }
            for elev in elevationLines {
                lines.append(elev)
            }
        }
        lines.append("")

        for day in days {
            lines.append(day.title.uppercased())
            if day.workouts.isEmpty {
                lines.append("  Rest / no sessions")
            } else {
                for workout in day.workouts {
                    lines.append("  \(workout.timePeriod) · \(workout.activityType) · \(workout.title) · \(workout.status)")
                    if !workout.detail.isEmpty {
                        lines.append("    \(workout.detail)")
                    }
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dates

    private static func weekRangeTitle(for week: WeekPlan, calendar: Calendar) -> String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: week.startOfWeek) else {
            return rangeFormatter.string(from: week.startOfWeek)
        }
        let start = week.startOfWeek
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            let month = monthFormatter.string(from: start)
            let y = calendar.component(.year, from: end)
            return "\(month) \(calendar.component(.day, from: start))–\(calendar.component(.day, from: end)), \(y)"
        }
        return "\(rangeFormatter.string(from: start)) – \(rangeFormatter.string(from: end))"
    }

    private static func dayTitle(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 1)) + "…"
    }

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()
}
