import Foundation

/// Unified workout entity per target data model. Not yet wired into stores or UI (Task 007).
struct Workout: Identifiable, Codable, Equatable {
    let id: UUID
    var metadata: RecordMetadata
    var plannedDate: Date
    var timePeriod: TimePeriod
    var title: String
    var activityType: ActivityType
    var runType: RunType?
    var plannedValues: PlannedValues
    var completedValues: CompletedValues
    var status: WorkoutStatus
    var source: WorkoutSource
    var linkedWorkoutTemplateId: UUID?
    var linkedWeeklyTemplateId: UUID?
    var linkedPeriodizedBlockId: UUID?
    var linkedHealthKitUUID: String?
    /// Legacy name-only template link; preserved for round-trip until Task 008.
    var templateName: String?
    var notes: String?
    var skipReason: String?

    init(
        id: UUID = UUID(),
        metadata: RecordMetadata = RecordMetadata(),
        plannedDate: Date,
        timePeriod: TimePeriod = .am,
        title: String,
        activityType: ActivityType,
        runType: RunType? = nil,
        plannedValues: PlannedValues = .empty,
        completedValues: CompletedValues = .empty,
        status: WorkoutStatus = .planned,
        source: WorkoutSource = .manual,
        linkedWorkoutTemplateId: UUID? = nil,
        linkedWeeklyTemplateId: UUID? = nil,
        linkedPeriodizedBlockId: UUID? = nil,
        linkedHealthKitUUID: String? = nil,
        templateName: String? = nil,
        notes: String? = nil,
        skipReason: String? = nil
    ) {
        self.id = id
        self.metadata = metadata
        self.plannedDate = plannedDate
        self.timePeriod = timePeriod
        self.title = title
        self.activityType = activityType
        self.runType = runType
        self.plannedValues = plannedValues
        self.completedValues = completedValues
        self.status = status
        self.source = source
        self.linkedWorkoutTemplateId = linkedWorkoutTemplateId
        self.linkedWeeklyTemplateId = linkedWeeklyTemplateId
        self.linkedPeriodizedBlockId = linkedPeriodizedBlockId
        self.linkedHealthKitUUID = linkedHealthKitUUID
        self.templateName = templateName
        self.notes = notes
        self.skipReason = skipReason
    }
}
