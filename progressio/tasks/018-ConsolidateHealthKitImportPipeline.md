# 018 - Consolidate HealthKit Import Pipeline

## Objective

Unify the two existing HealthKit import entry points into a single import pipeline before dedup and matching work.

## Required Context

Read:

- docs/AppleHealth.md
- tasks/ImplementationNotes.md

## Current State (from audit)

**Two duplicate import paths:**

```
Path A: SettingsView → fetchRecentRuns (7 days) → importUnattachedRuns
Path B: WeekPlannerView.onAppear → startObservingRuns → fetchRecentRuns (3 days) → importUnattachedRuns
```

- `hasAttachedRun(with:)` in `WeekPlannerViewModel` is **dead code** (never called).
- `HealthKitManager` only queries running workouts.
- Observer re-fires and re-fetches on every HealthKit update.

## Scope

- Create single `HealthKitImportService` (or equivalent) used by Settings and planner observer
- Consolidate date range policy (configurable, single default)
- Remove or wire `hasAttachedRun(with:)` into import boundary
- Ensure observer does not trigger redundant full re-import when nothing new exists
- Centralize mapping `HKWorkout` → import DTO (precursor to `ImportedHealthWorkoutReference`)

## Out of Scope

- UUID dedup logic changes (Task 019).
- User matching prompt (Task 020).
- Importing bike/walk workouts (Task 019 or later).
- History UI.

## Implementation Notes

Settings and `WeekPlannerView` should call the same service method.

Log import runs for debugging duplicate issues.

Do not change dedup semantics yet — only consolidate entry points.

## Acceptance Criteria

- The app builds.
- Settings import and background observer use the same pipeline.
- No duplicate import code paths in view layer.
- `hasAttachedRun` either removed or used at import boundary.
- Existing attach-to-planned flow still works.

## Manual QA Checklist

- [ ] Import from Settings: runs appear in unattached list.
- [ ] Open planner: observer does not create duplicate entries beyond dedup layer.
- [ ] Attach run to planned session still works.
