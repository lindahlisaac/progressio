import Foundation

/// Snapshot of a workout stored inside a weekly template day.
/// Independent from live week-plan workouts; apply always creates new workout IDs.
struct WeeklyTemplateWorkoutEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var timePeriod: TimePeriod
    var activityType: ActivityType
    var runType: RunType?
    var title: String
    var notes: String?
    var plannedValues: PlannedValues
    var linkedWorkoutTemplateId: UUID?
    var templateName: String?

    init(
        id: UUID = UUID(),
        timePeriod: TimePeriod = .am,
        activityType: ActivityType,
        runType: RunType? = nil,
        title: String,
        notes: String? = nil,
        plannedValues: PlannedValues = .empty,
        linkedWorkoutTemplateId: UUID? = nil,
        templateName: String? = nil
    ) {
        self.id = id
        self.timePeriod = timePeriod
        self.activityType = activityType
        self.runType = runType
        self.title = title
        self.notes = notes
        self.plannedValues = plannedValues
        self.linkedWorkoutTemplateId = linkedWorkoutTemplateId
        self.templateName = templateName
    }

    static func blank(activityType: ActivityType) -> WeeklyTemplateWorkoutEntry {
        let notes: String = {
            switch activityType {
            case .strength: return "Strength session"
            case .bike: return "Planned bike"
            case .stairMaster: return "Planned StairMaster"
            case .roadRun, .trailRun, .walk: return "Planned \(activityType.rawValue.lowercased())"
            }
        }()
        return WeeklyTemplateWorkoutEntry(
            activityType: activityType,
            title: activityType.defaultTitle,
            notes: notes
        )
    }

    /// Planned-only snapshot from a live workout (no completed values).
    static func snapshot(from workout: Workout) -> WeeklyTemplateWorkoutEntry {
        WeeklyTemplateWorkoutEntry(
            id: UUID(),
            timePeriod: workout.timePeriod,
            activityType: workout.activityType,
            runType: workout.runType,
            title: workout.title,
            notes: workout.notes,
            plannedValues: workout.plannedValues,
            linkedWorkoutTemplateId: workout.linkedWorkoutTemplateId,
            templateName: workout.templateName
        )
    }

    static func from(session: PlannedSession) -> WeeklyTemplateWorkoutEntry {
        let workout = LegacySessionMapper.workout(from: session, plannedDate: Date())
        return WeeklyTemplateWorkoutEntry(
            id: UUID(),
            timePeriod: workout.timePeriod,
            activityType: workout.activityType,
            runType: workout.runType,
            title: workout.title,
            notes: workout.notes,
            plannedValues: workout.plannedValues,
            linkedWorkoutTemplateId: workout.linkedWorkoutTemplateId,
            templateName: workout.templateName
        )
    }

    func makeWorkout(plannedDate: Date, linkedWeeklyTemplateId: UUID?, linkedPeriodizedBlockId: UUID? = nil) -> Workout {
        Workout(
            id: UUID(),
            plannedDate: plannedDate,
            timePeriod: timePeriod,
            title: title,
            activityType: activityType,
            runType: runType,
            plannedValues: plannedValues,
            completedValues: .empty,
            status: .planned,
            source: .template,
            linkedWorkoutTemplateId: linkedWorkoutTemplateId,
            linkedWeeklyTemplateId: linkedWeeklyTemplateId,
            linkedPeriodizedBlockId: linkedPeriodizedBlockId,
            templateName: templateName,
            notes: notes
        )
    }
}
