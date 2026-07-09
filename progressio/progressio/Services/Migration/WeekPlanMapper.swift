import Foundation

/// Converts between in-memory `WeekPlan` and on-disk `MigratedWeekPlan`.
enum WeekPlanMapper {

    static func migratedWeekPlan(from weekPlan: WeekPlan, fileModificationDate: Date? = nil) -> MigratedWeekPlan {
        _ = fileModificationDate
        let days = weekPlan.days.map { day in
            MigratedDayPlan(
                id: day.id,
                date: day.date,
                workouts: day.workouts,
                updatedAt: day.updatedAt,
                etag: day.etag
            )
        }

        return MigratedWeekPlan(
            startOfWeek: weekPlan.startOfWeek,
            days: days,
            schemaVersion: weekPlan.schemaVersion,
            createdAt: weekPlan.createdAt,
            updatedAt: weekPlan.updatedAt,
            isDeleted: weekPlan.isDeleted,
            deletedAt: weekPlan.deletedAt,
            etag: weekPlan.etag
        )
    }

    static func weekPlan(from migrated: MigratedWeekPlan) -> WeekPlan {
        let days = migrated.days.map { day in
            DayPlan(
                id: day.id,
                date: day.date,
                workouts: day.workouts,
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
}
