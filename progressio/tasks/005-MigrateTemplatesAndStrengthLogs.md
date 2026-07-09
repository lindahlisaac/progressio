# 005 - Migrate Templates and Strength Logs

## Objective

Migrate `templates.json`, `weeklyTemplates.json`, and `strengthlog-*.json` to align with the new model layer.

## Required Context

Read:

- docs/DataModel.md
- docs/Templates.md
- docs/SyncAndMigration.md
- tasks/ImplementationNotes.md
- tasks/002-WorkoutTypesAndMetadata.md
- tasks/003-MigrationInfrastructure.md
- tasks/004-MigrateWeekPlansAndWorkouts.md

## Current State (from audit)

- `StrengthTemplate` serves both strength and run templates via `TemplateCategory`.
- `WeeklyTemplate` embeds full `PlannedSession` structs (with original IDs).
- Strength completion is in `Documents/strengthlog-{sessionID}.json`, not in week plan JSON.
- Strength logs are **not synced** to CloudKit.

## Scope

Implement migration for:

**templates.json**

- Add `schemaVersion`, `createdAt`, `updatedAt`, `isDeleted` metadata to `StrengthTemplate`
- Preserve existing template IDs and exercise data

**weeklyTemplates.json**

- Add metadata fields to `WeeklyTemplate` and `DayTemplate`
- Sessions inside weekly templates remain in migratable form (snapshot refactor is Task 010)

**strengthlog-*.json**

- Migrate strength log files to include metadata (`createdAt`, `updatedAt`, `schemaVersion`)
- Optionally embed a reference in migrated `Workout.plannedValues` / `completedValues` strength snapshot fields where a matching session ID exists in week plans

Register these as migration steps in the runner from Task 003.

## Out of Scope

- Splitting endurance templates from strength (Task 009).
- Weekly template snapshot-on-apply fix (Task 010).
- CloudKit strength log sync (Task 021).
- View model rewiring (Task 007).

## Implementation Notes

Do not rename templates or change template IDs.

Weekly template embedded sessions keep their IDs for now — Task 010 fixes the apply collision separately.

If strength logs cannot be matched to a workout, leave them as standalone files and log a warning.

## Acceptance Criteria

- The app builds.
- Existing templates load after migration with preserved IDs and content.
- Weekly templates load after migration.
- Strength logs for existing sessions remain accessible.
- No template or log data is silently dropped.

## Manual QA Checklist

- [ ] Strength templates: exercises and sets intact.
- [ ] Run templates: category and run type intact.
- [ ] Weekly templates: all days and sessions intact.
- [ ] Open strength session with existing log: sets/reps still visible.
- [ ] Apply weekly template still works (even if ID collision bug remains).
