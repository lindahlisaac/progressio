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

    var hasPlannedEnduranceDetail: Bool {
        activityType != .strength
            && (!plannedDistance.isEmpty || !plannedDuration.isEmpty || !plannedElevation.isEmpty
                || runType != nil)
    }

    var hasCompletedEnduranceDetail: Bool {
        activityType != .strength
            && (!actualDistance.isEmpty || !actualDuration.isEmpty || !actualElevation.isEmpty
                || linkedHealthKitUUID != nil)
    }

    static func strength(
        plannedDate: Date,
        title: String,
        notes: String? = nil,
        templateName: String? = nil,
        source: WorkoutSource = .manual
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
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
        title: String,
        imported: Bool,
        notes: String? = nil
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            title: title,
            activityType: .roadRun,
            status: imported ? .imported : .planned,
            source: imported ? .appleHealth : .manual,
            notes: notes
        )
    }

    static func ride(
        plannedDate: Date,
        title: String,
        imported: Bool,
        notes: String? = nil
    ) -> Workout {
        Workout(
            plannedDate: plannedDate,
            title: title,
            activityType: .bike,
            status: imported ? .imported : .planned,
            source: imported ? .appleHealth : .manual,
            notes: notes
        )
    }

    static func from(template: StrengthTemplate, plannedDate: Date) -> Workout {
        if template.category == .run {
            var planned = PlannedValues.empty
            planned.plannedDescription = template.note
            return Workout(
                plannedDate: plannedDate,
                title: template.name,
                activityType: .roadRun,
                runType: template.runCategory.flatMap(RunType.init(runCategory:)),
                plannedValues: planned,
                status: .planned,
                source: .template,
                linkedWorkoutTemplateId: template.id,
                templateName: template.name,
                notes: "From template"
            )
        }

        var planned = PlannedValues.empty
        planned.plannedStrengthRoutineSnapshot = TemplateSnapshot.plannedSnapshot(from: template)
        return Workout(
            plannedDate: plannedDate,
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

    mutating func touchUpdatedAt(_ date: Date = Date()) {
        metadata.updatedAt = date
    }
}

extension WorkoutStatus {
    var tint: Color {
        switch self {
        case .planned: return .blue.opacity(0.8)
        case .completed, .partiallyCompleted: return .green.opacity(0.85)
        case .imported: return .orange.opacity(0.85)
        case .skipped: return .gray.opacity(0.8)
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
        actualDistance: String?,
        actualDuration: String?,
        actualElevation: String?,
        status: WorkoutStatus
    ) {
        workout.title = title
        workout.runType = runType
        workout.plannedValues.plannedDistance = emptyToNil(plannedDistance)
        workout.plannedValues.plannedDuration = emptyToNil(plannedDuration)
        workout.plannedValues.plannedElevationGain = emptyToNil(plannedElevation)
        workout.status = status

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
