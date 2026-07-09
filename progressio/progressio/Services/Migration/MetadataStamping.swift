import Foundation

/// Applies sync metadata defaults when migrating legacy persisted records.
enum MetadataStamping {

    static func stamp(
        _ template: inout StrengthTemplate,
        fallbackTimestamp: Date = Date()
    ) {
        if template.schemaVersion < WorkoutSchema.currentVersion {
            template.schemaVersion = WorkoutSchema.currentVersion
        }
        if template.createdAt == nil {
            template.createdAt = template.updatedAt ?? fallbackTimestamp
        }
        template.updatedAt = template.updatedAt ?? fallbackTimestamp
    }

    static func stamp(
        _ template: inout WeeklyTemplate,
        fallbackTimestamp: Date = Date()
    ) {
        if template.schemaVersion < WorkoutSchema.currentVersion {
            template.schemaVersion = WorkoutSchema.currentVersion
        }
        if template.createdAt == nil {
            template.createdAt = template.updatedAt ?? fallbackTimestamp
        }
        template.updatedAt = template.updatedAt ?? fallbackTimestamp

        for index in template.days.indices {
            stamp(&template.days[index], fallbackTimestamp: fallbackTimestamp)
        }
    }

    static func stamp(
        _ day: inout DayTemplate,
        fallbackTimestamp: Date = Date()
    ) {
        if day.schemaVersion < WorkoutSchema.currentVersion {
            day.schemaVersion = WorkoutSchema.currentVersion
        }
        if day.createdAt == nil {
            day.createdAt = day.updatedAt ?? fallbackTimestamp
        }
        day.updatedAt = day.updatedAt ?? fallbackTimestamp
    }

    static func stamp(
        _ log: inout StrengthLogState,
        fallbackTimestamp: Date = Date()
    ) {
        if log.schemaVersion < WorkoutSchema.currentVersion {
            log.schemaVersion = WorkoutSchema.currentVersion
        }
        if log.createdAt == nil {
            log.createdAt = log.updatedAt ?? fallbackTimestamp
        }
        log.updatedAt = log.updatedAt ?? fallbackTimestamp
    }
}
