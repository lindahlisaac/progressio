# 004 - Migrate Week Plans and Workouts

## Objective

Migrate `weekplan-*.json` data from legacy `PlannedSession` to the new `Workout` model.

## Required Context

Read:

- docs/DataModel.md
- docs/SyncAndMigration.md
- tasks/ImplementationNotes.md
- tasks/002-WorkoutTypesAndMetadata.md (types must exist)
- tasks/003-MigrationInfrastructure.md (runner must exist)

## Current State (from audit)

- `WeekPlan` contains `[DayPlan]` each with `[PlannedSession]`.
- `runDetail` / `actualRun` hold planned vs completed endurance data.
- `PlanStatus.unplanned` maps to docs' imported/ad-hoc semantics.
- `SessionKind.cycle` maps to docs' Bike.
- No `source`, `timePeriod`, or top-level `linkedHealthKitUUID`.

## Scope

Implement migration step(s) that:

- Read existing `weekplan-*.json` files in legacy format
- Convert each `PlannedSession` to `Workout` using mapping helpers from Task 002
- Map `SessionKind` → `ActivityType` (Run → Road Run default; Cycle → Bike; Strength → Strength)
- Map `PlanStatus` → `WorkoutStatus` (`unplanned` → `imported`)
- Move `runDetail` fields into `plannedValues`; `actualRun` into `completedValues`
- Preserve stable session `id` as workout `id`
- Set `createdAt`/`updatedAt` from existing `updatedAt` or file mtime
- Infer `linkedHealthKitUUID` from `actualRun.hkWorkoutUUID` or `runDetail.hkWorkoutUUID`
- Write migrated week plans in new format

Update `FileWeekPlanStore` / `CloudWeekPlanStore` to read both formats during transition, or migrate all files on first launch.

## Out of Scope

- Template migration (Task 005).
- Strength log file migration (Task 005).
- View model rewiring (Task 007).
- Apple Health import behavior changes.

## Implementation Notes

Preserve all planned and completed values — never merge them during migration.

Default `timePeriod` to AM if not inferable from data.

Default `source` to `.manual`; set `.template` when `templateName` is present; set `.appleHealth` when HK UUID present on completed values.

**Cross-device / CloudKit:** A device that has already migrated must tolerate legacy-format week plan payloads pulled from CloudKit (from a device that has not migrated yet). Decode via dual-read, migrate on load, and do not overwrite newer local migrated data with stale remote blobs. Document the chosen merge policy in code comments.

## Acceptance Criteria

- The app builds.
- Existing week plan files migrate without data loss.
- Planned and completed values remain separate after migration.
- Workout IDs are stable (same UUIDs as original sessions).
- iCloud week plan payloads remain loadable (may dual-read during transition).
- Device that migrated locally can pull a legacy-format week plan from CloudKit without crash or data loss.
- Migrated week synced to CloudKit is loadable on a second device (simulator or physical).

## Manual QA Checklist

- [ ] Week with planned runs: planned values preserved.
- [ ] Week with completed runs: completed values preserved, planned untouched.
- [ ] Week with skipped sessions: status and note preserved.
- [ ] Week with HealthKit-attached runs: UUID preserved.
- [ ] Navigate prev/next week: all weeks load.
- [ ] **Two devices:** Device A migrates and syncs; Device B pulls week plan — no crash, data intact.
- [ ] **Two devices:** Device B still on legacy local data pulls migrated CloudKit payload — migrates on load without loss.
