# 007 - Wire View Models to Workout Model

## Objective

Switch `WeekPlannerViewModel` and related code from legacy `PlannedSession` to the new `Workout` model while preserving all existing planner behavior.

## Required Context

Read:

- docs/Architecture.md
- docs/DataModel.md
- tasks/ImplementationNotes.md
- tasks/002-WorkoutTypesAndMetadata.md
- tasks/004-MigrateWeekPlansAndWorkouts.md

## Current State (from audit)

- `WeekPlannerViewModel` (~670 lines) owns week navigation, session CRUD, template apply, HealthKit import, export/import, and sync.
- Views (`WeekPlannerView`, `RunDetailView`, `RideDetailView`, `StrengthLogView`, `UnattachedRunsView`) all take `PlannedSession`.
- `DayPlan.sessions` is `[PlannedSession]`.

## Scope

- Replace `PlannedSession` with `Workout` in `DayPlan`, `WeekPlan`, and `WeekPlannerViewModel`
- Update all planner views to use `Workout` (adapter extensions acceptable to minimize view churn)
- Preserve existing behavior: add run/ride/strength, status toggle, skip, delete, attach run, weekly template apply, export/import
- Update `RunDetailView` / `RideDetailView` to read/write `plannedValues` / `completedValues`
- Keep strength log file storage working (snapshot integration is Task 008)

## Out of Scope

- Template snapshot-on-apply (Task 008).
- New activity types in UI (Task 011).
- New status indicators (Task 012).
- HealthKit changes (Tasks 018–020).
- Splitting `WeekPlannerViewModel` into smaller types (optional, not required).

## Implementation Notes

This is the highest-regression task in the foundation phase. Change incrementally and keep the app buildable.

Consider thin typealiases or extensions on `Workout` for properties views already expect (`title`, `kind`, etc.) to reduce diff size.

Do not change user-visible flows — only the underlying model.

**Large diff guidance:** If the change set grows unwieldy, split implementation (and review) into ordered sub-steps while keeping the app buildable after each: (1) `DayPlan` / `WeekPlan` + stores, (2) `WeekPlannerViewModel`, (3) planner views. Do not merge partial legacy/new type usage across layers.

## Acceptance Criteria

- The app builds.
- Week planner: add, edit, complete, skip, and delete workouts all work.
- Run/ride detail: planned and completed values remain separate.
- Week navigation works.
- Export/import current week still works.
- HealthKit attach flow still works (no dedup changes yet).
- Weekly template apply still works.

## Manual QA Checklist

- [ ] Add run, ride, strength to a day.
- [ ] Complete a run with actual distance — planned distance unchanged.
- [ ] Skip a workout with note.
- [ ] Delete a workout.
- [ ] Prev/next week navigation.
- [ ] Export and re-import week.
- [ ] Attach unattached HealthKit run to planned session.
