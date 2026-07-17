import Foundation

/// Shared helpers for sync metadata stamping and soft deletes.
enum SyncMetadata {

    static func softDelete(_ template: StrengthTemplate, at date: Date = Date()) -> StrengthTemplate {
        var copy = template
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ template: EnduranceTemplate, at date: Date = Date()) -> EnduranceTemplate {
        var copy = template
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ template: WeeklyTemplate, at date: Date = Date()) -> WeeklyTemplate {
        var copy = template
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ block: PeriodizedBlockTemplate, at date: Date = Date()) -> PeriodizedBlockTemplate {
        var copy = block
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ run: UnattachedRun, at date: Date = Date()) -> UnattachedRun {
        var copy = run
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ reference: ImportedHealthWorkoutReference, at date: Date = Date()) -> ImportedHealthWorkoutReference {
        var copy = reference
        copy.isDeleted = true
        copy.deletedAt = date
        copy.updatedAt = date
        return copy
    }

    static func softDelete(_ workout: Workout, at date: Date = Date()) -> Workout {
        var copy = workout
        copy.metadata.isDeleted = true
        copy.metadata.deletedAt = date
        copy.metadata.updatedAt = date
        return copy
    }

    static func stampNewRecord(_ template: inout StrengthTemplate, at date: Date = Date()) {
        if template.createdAt == nil {
            template.createdAt = date
        }
        template.updatedAt = date
        if template.schemaVersion < WorkoutSchema.currentVersion {
            template.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampNewRecord(_ template: inout EnduranceTemplate, at date: Date = Date()) {
        if template.createdAt == nil {
            template.createdAt = date
        }
        template.updatedAt = date
        if template.schemaVersion < WorkoutSchema.currentVersion {
            template.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampNewRecord(_ template: inout WeeklyTemplate, at date: Date = Date()) {
        if template.createdAt == nil {
            template.createdAt = date
        }
        template.updatedAt = date
        if template.schemaVersion < WorkoutSchema.currentVersion {
            template.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampNewRecord(_ block: inout PeriodizedBlockTemplate, at date: Date = Date()) {
        if block.createdAt == nil {
            block.createdAt = date
        }
        block.updatedAt = date
        if block.schemaVersion < WorkoutSchema.currentVersion {
            block.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampNewRecord(_ run: inout UnattachedRun, at date: Date = Date()) {
        if run.createdAt == nil {
            run.createdAt = date
        }
        run.updatedAt = date
        if run.schemaVersion < WorkoutSchema.currentVersion {
            run.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampNewRecord(_ reference: inout ImportedHealthWorkoutReference, at date: Date = Date()) {
        if reference.createdAt == nil {
            reference.createdAt = date
        }
        reference.updatedAt = date
        if reference.schemaVersion < WorkoutSchema.currentVersion {
            reference.schemaVersion = WorkoutSchema.currentVersion
        }
    }

    static func stampSave(_ template: inout StrengthTemplate, at date: Date = Date()) {
        template.updatedAt = date
    }

    static func stampSave(_ template: inout EnduranceTemplate, at date: Date = Date()) {
        template.updatedAt = date
    }

    static func stampSave(_ template: inout WeeklyTemplate, at date: Date = Date()) {
        template.updatedAt = date
    }

    static func stampSave(_ block: inout PeriodizedBlockTemplate, at date: Date = Date()) {
        block.updatedAt = date
    }

    static func stampSave(_ run: inout UnattachedRun, at date: Date = Date()) {
        run.updatedAt = date
    }

    static func stampSave(_ reference: inout ImportedHealthWorkoutReference, at date: Date = Date()) {
        reference.updatedAt = date
    }

    static func stampSave(_ week: inout WeekPlan, at date: Date = Date()) {
        week.updatedAt = date
    }

    static func stampLegacy(_ run: inout UnattachedRun, fallbackTimestamp: Date = Date()) {
        if run.schemaVersion < WorkoutSchema.currentVersion {
            run.schemaVersion = WorkoutSchema.currentVersion
        }
        if run.createdAt == nil {
            run.createdAt = run.updatedAt ?? fallbackTimestamp
        }
        run.updatedAt = run.updatedAt ?? fallbackTimestamp
    }

    static func stampLegacy(_ plan: inout MigratedWeekPlan, fallbackTimestamp: Date = Date()) {
        if plan.schemaVersion < WorkoutSchema.currentVersion {
            plan.schemaVersion = WorkoutSchema.currentVersion
        }
        if plan.createdAt == nil {
            plan.createdAt = plan.updatedAt ?? fallbackTimestamp
        }
        plan.updatedAt = plan.updatedAt ?? fallbackTimestamp
    }

    static func stampLegacy(_ plan: inout WeekPlan, fallbackTimestamp: Date = Date()) {
        if plan.schemaVersion < WorkoutSchema.currentVersion {
            plan.schemaVersion = WorkoutSchema.currentVersion
        }
        if plan.createdAt == nil {
            plan.createdAt = plan.updatedAt ?? fallbackTimestamp
        }
        plan.updatedAt = plan.updatedAt ?? fallbackTimestamp
    }
}
