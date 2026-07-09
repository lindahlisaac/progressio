import Foundation

/// Converts between legacy `WeekPlan` and migrated `MigratedWeekPlan`.
enum WeekPlanMapper {

    static func migratedWeekPlan(from legacy: WeekPlan, fileModificationDate: Date? = nil) -> MigratedWeekPlan {
        let fallbackTimestamp = fileModificationDate ?? legacy.updatedAt ?? Date()
        let days = legacy.days.map { day in
            MigratedDayPlan(
                id: day.id,
                date: day.date,
                workouts: day.sessions.map { session in
                    workout(from: session, plannedDate: day.date, fallbackTimestamp: fallbackTimestamp)
                },
                updatedAt: day.updatedAt,
                etag: day.etag
            )
        }

        return MigratedWeekPlan(
            startOfWeek: legacy.startOfWeek,
            days: days,
            schemaVersion: legacy.schemaVersion,
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt,
            isDeleted: legacy.isDeleted,
            deletedAt: legacy.deletedAt,
            etag: legacy.etag
        )
    }

    static func legacyWeekPlan(from migrated: MigratedWeekPlan) -> WeekPlan {
        let days = migrated.days.map { day in
            DayPlan(
                id: day.id,
                date: day.date,
                sessions: day.workouts.map { LegacySessionMapper.plannedSession(from: $0) },
                updatedAt: day.updatedAt,
                etag: day.etag
            )
        }

        return WeekPlan(
            startOfWeek: migrated.startOfWeek,
            days: days,
            schemaVersion: migrated.schemaVersion,
            createdAt: migrated.createdAt,
            updatedAt: migrated.updatedAt,
            isDeleted: migrated.isDeleted,
            deletedAt: migrated.deletedAt,
            etag: migrated.etag
        )
    }

    private static func workout(
        from session: PlannedSession,
        plannedDate: Date,
        fallbackTimestamp: Date
    ) -> Workout {
        var workout = LegacySessionMapper.workout(from: session, plannedDate: plannedDate)
        if session.updatedAt == nil {
            workout.metadata.createdAt = fallbackTimestamp
            workout.metadata.updatedAt = fallbackTimestamp
        }
        return workout
    }
}
