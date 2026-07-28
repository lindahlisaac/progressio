import Foundation
import SwiftUI

extension Workout {

    var sessionKind: SessionKind { activityType.sessionKind }

    var displayNote: String? {
        if status == .skipped { return skipReason }
        return notes
    }

    var plannedDistance: String { plannedValues.plannedDistance ?? "" }
    var actualDistance: String { completedValues.completedDistance ?? "" }
    var plannedElevation: String { plannedValues.plannedElevationGain ?? "" }
    var actualElevation: String { completedValues.completedElevationGain ?? "" }
    var plannedDuration: String { plannedValues.plannedDuration ?? "" }
    var actualDuration: String { completedValues.completedDuration ?? "" }
    var plannedLevel: String { plannedValues.plannedLevel ?? "" }
    var actualLevel: String { completedValues.completedLevel ?? "" }

    var hasPlannedEnduranceDetail: Bool {
        activityType != .strength
            && (!plannedDistance.isEmpty || !plannedDuration.isEmpty || !plannedElevation.isEmpty
                || !plannedLevel.isEmpty || runType != nil)
    }

    var hasCompletedEnduranceDetail: Bool {
        activityType != .strength
            && (!actualDistance.isEmpty || !actualDuration.isEmpty || !actualElevation.isEmpty
                || !actualLevel.isEmpty || linkedHealthKitUUID != nil)
    }

    static func strength(
        plannedDate: Date,
        timePeriod: TimePeriod = .am,
        title: String,
        notes: String? = nil,
        templateName: String? = nil,
        source: WorkoutSource = .manual
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: title,
            activityType: .strength,
            status: .planned,
            source: source,
            templateName: templateName,
            notes: notes
        )
    }

    static func run(
        plannedDate: Date,
        timePeriod: TimePeriod = .am,
        title: String,
        imported: Bool,
        notes: String? = nil
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: title,
            activityType: .roadRun,
            status: imported ? .imported : .planned,
            source: imported ? .appleHealth : .manual,
            notes: notes
        )
    }

    static func ride(
        plannedDate: Date,
        timePeriod: TimePeriod = .am,
        title: String,
        imported: Bool,
        notes: String? = nil
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: title,
            activityType: .bike,
            status: imported ? .imported : .planned,
            source: imported ? .appleHealth : .manual,
            notes: notes
        )
    }

    /// Manual blank workout for any planner activity type.
    static func manual(
        activityType: ActivityType,
        plannedDate: Date,
        timePeriod: TimePeriod = .am,
        title: String? = nil,
        notes: String? = nil
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: title ?? activityType.defaultTitle,
            activityType: activityType,
            status: .planned,
            source: .manual,
            notes: notes
        )
    }

    static func from(template: StrengthTemplate, plannedDate: Date, timePeriod: TimePeriod = .am) -> Workout {
        var planned = PlannedValues.empty
        planned.plannedStrengthRoutineSnapshot = TemplateSnapshot.plannedSnapshot(from: template)
        return Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: template.name,
            activityType: .strength,
            plannedValues: planned,
            status: .planned,
            source: .template,
            linkedWorkoutTemplateId: template.id,
            templateName: template.name,
            notes: "From template"
        )
    }

    static func from(template: EnduranceTemplate, plannedDate: Date, timePeriod: TimePeriod = .am) -> Workout {
        var planned = PlannedValues.empty
        planned.plannedDistance = template.plannedDistance
        planned.plannedDuration = template.plannedDuration
        planned.plannedElevationGain = template.plannedElevationGain
        planned.plannedLevel = template.plannedLevel
        planned.plannedDescription = template.description
        planned.plannedIntensityRPE = template.intensityRPE
        planned.plannedRoute = template.route
        return Workout(
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: template.name,
            activityType: template.activityType,
            runType: template.runType,
            plannedValues: planned,
            status: .planned,
            source: .template,
            linkedWorkoutTemplateId: template.id,
            templateName: template.name,
            notes: template.description ?? "From template"
        )
    }

    mutating func touchUpdatedAt(_ date: Date = Date()) {
        metadata.updatedAt = date
    }
}

extension WorkoutStatus {
    /// Short badge label for planner rows (keeps Partially Completed compact).
    var badgeLabel: String {
        switch self {
        case .planned: return "Planned"
        case .completed: return "Done"
        case .partiallyCompleted: return "Partial"
        case .imported: return "Imported"
        case .skipped: return "Skipped"
        }
    }

    var tint: Color {
        switch self {
        case .planned: return .blue.opacity(0.85)
        case .completed: return .green.opacity(0.85)
        case .partiallyCompleted: return Color(red: 0.15, green: 0.55, blue: 0.45).opacity(0.9)
        case .imported: return .orange.opacity(0.9)
        case .skipped: return .gray.opacity(0.75)
        }
    }

    var rowToggleLabel: String {
        switch self {
        case .imported: return "Mark Planned"
        case .planned: return "Mark Complete"
        case .completed, .partiallyCompleted: return "Mark Planned"
        case .skipped: return "Mark Planned"
        }
    }
}

enum WorkoutEditing {

    static func applyEnduranceSave(
        to workout: inout Workout,
        title: String,
        runType: RunType?,
        plannedDistance: String,
        plannedDuration: String,
        plannedElevation: String,
        plannedLevel: String? = nil,
        actualDistance: String?,
        actualDuration: String?,
        actualElevation: String?,
        actualLevel: String? = nil,
        status: WorkoutStatus,
        timePeriod: TimePeriod? = nil,
        activityType: ActivityType? = nil,
        notes: String? = nil
    ) {
        workout.title = title
        workout.runType = runType
        if let timePeriod {
            workout.timePeriod = timePeriod
        }
        if let activityType, activityType.sessionKind == .run || activityType == .stairMaster {
            workout.activityType = activityType
        }
        workout.plannedValues.plannedDistance = emptyToNil(plannedDistance)
        workout.plannedValues.plannedDuration = emptyToNil(plannedDuration)
        workout.plannedValues.plannedElevationGain = emptyToNil(plannedElevation)
        if let plannedLevel {
            workout.plannedValues.plannedLevel = emptyToNil(plannedLevel)
        }
        workout.status = status
        if let notes {
            workout.notes = emptyToNil(notes)
        }

        if let actualDistance {
            let trimmed = actualDistance.trimmingCharacters(in: .whitespacesAndNewlines)
            workout.completedValues.completedDistance = trimmed.isEmpty ? nil : trimmed
        }
        if let actualDuration {
            workout.completedValues.completedDuration = emptyToNil(actualDuration)
        }
        if let actualElevation {
            workout.completedValues.completedElevationGain = emptyToNil(actualElevation)
        }
        if let actualLevel {
            workout.completedValues.completedLevel = emptyToNil(actualLevel)
        }

        if status == .completed, workout.completedValues.completedAt == nil {
            workout.completedValues.completedAt = Date()
        }
        workout.touchUpdatedAt()
    }

    static func applyAttachedRun(_ detail: RunDetailData, to workout: inout Workout) {
        workout.completedValues.completedDistance = emptyToNil(detail.distance)
        workout.completedValues.completedDuration = emptyToNil(detail.duration)
        workout.completedValues.completedElevationGain = detail.elevationGain.flatMap(emptyToNil)
        workout.completedValues.completedHeartRateAverage = emptyToNil(detail.averageHR)
        workout.completedValues.completedDescription = emptyToNil(detail.notes)
        workout.completedValues.completedAt = detail.eventDate ?? Date()
        workout.linkedHealthKitUUID = detail.hkWorkoutUUID
        if let category = detail.category {
            workout.runType = RunType(runCategory: category)
        }
        workout.status = .completed
        workout.touchUpdatedAt()
    }

    static func detachCompletedRun(from workout: inout Workout) -> RunDetailData? {
        guard hasCompletedEnduranceDetail(workout) else { return nil }
        let detail = RunDetailData(
            title: workout.title,
            notes: workout.completedValues.completedDescription ?? "",
            distance: workout.completedValues.completedDistance ?? "",
            duration: workout.completedValues.completedDuration ?? "",
            averageHR: workout.completedValues.completedHeartRateAverage ?? "",
            category: workout.runType?.runCategory,
            hkWorkoutUUID: workout.linkedHealthKitUUID,
            elevationGain: workout.completedValues.completedElevationGain,
            eventDate: workout.completedValues.completedAt,
            updatedAt: workout.completedValues.completedAt
        )
        workout.completedValues = .empty
        workout.linkedHealthKitUUID = nil
        if workout.status == .completed && !workout.hasPlannedEnduranceDetail {
            workout.status = .planned
        }
        workout.touchUpdatedAt()
        return detail
    }

    static func completedRunDetail(from workout: Workout) -> RunDetailData {
        RunDetailData(
            title: workout.title,
            notes: workout.completedValues.completedDescription ?? "",
            distance: workout.completedValues.completedDistance ?? "",
            duration: workout.completedValues.completedDuration ?? "",
            averageHR: workout.completedValues.completedHeartRateAverage ?? "",
            category: workout.runType?.runCategory,
            hkWorkoutUUID: workout.linkedHealthKitUUID,
            elevationGain: workout.completedValues.completedElevationGain,
            eventDate: workout.completedValues.completedAt,
            updatedAt: workout.completedValues.completedAt
        )
    }

    private static func hasCompletedEnduranceDetail(_ workout: Workout) -> Bool {
        workout.hasCompletedEnduranceDetail
    }

    private static func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
