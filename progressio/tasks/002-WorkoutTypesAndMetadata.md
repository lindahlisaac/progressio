# 002 - Workout Types and Metadata

## Objective

Introduce the target workout domain types alongside the existing legacy models, without yet migrating data or rewiring the app.

## Required Context

Read:

- docs/DataModel.md
- docs/Architecture.md
- docs/SyncAndMigration.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `PlannedSession` in `Models/Models.swift` is the de-facto workout.
- Planned run/ride data lives in `runDetail`; completed data in `actualRun`.
- Strength completion lives in separate `strengthlog-{id}.json` files.
- No `schemaVersion`, `createdAt`, `isDeleted`, `WorkoutSource`, or `timePeriod`.
- Enums: `SessionKind` (Strength/Run/Cycle), `PlanStatus` (includes `unplanned`).

## Scope

Add new types (new file(s) under `Models/` recommended) for:

- `Workout` — target unified workout entity per docs
- `PlannedValues` and `CompletedValues` — embedded structs keeping planned/completed separate
- `ActivityType` — Road Run, Trail Run, Walk, Bike, Strength
- `WorkoutStatus` — Planned, Completed, Skipped, Imported, Partially Completed
- `WorkoutSource` — Manual, Template, Apple Health
- `TimePeriod` — AM, PM
- `RunType` — Easy, Recovery, Tempo, Threshold, VO2, Long Run, Race
- `RecordMetadata` or equivalent — `schemaVersion`, `createdAt`, `updatedAt`, `isDeleted`, `deletedAt`

Include mapping helpers (e.g. `LegacySessionMapper`) that can convert between legacy `PlannedSession` and new `Workout`, but do **not** call them from stores or view models yet.

## Out of Scope

- Do not migrate persisted JSON files yet (Task 004).
- Do not change store protocols or CloudKit payloads yet (Task 006).
- Do not change view models or views yet (Task 007).
- Do not remove legacy types — they remain in use until Task 007.

## Implementation Notes

Keep legacy `Models.swift` compiling unchanged. New types should be additive.

Favor small embedded structs for planned/completed values rather than modality-specific top-level models.

Define a current `schemaVersion` constant for new records.

## Acceptance Criteria

- The app builds with no behavior change.
- New `Workout` type and related enums exist and match docs semantics.
- Mapping helpers exist between `PlannedSession` ↔ `Workout` (testable in isolation).
- Legacy types and all existing screens still work unchanged.

## Manual QA Checklist

- [ ] App launches and week planner works as before.
- [ ] Templates tab works as before.
- [ ] Settings import/sync works as before.
