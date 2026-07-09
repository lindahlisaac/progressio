# 009 - Endurance Template Model Split

## Objective

Split endurance workout templates from the combined `StrengthTemplate` type into a dedicated `EnduranceTemplate` model.

## Required Context

Read:

- docs/Templates.md
- docs/DataModel.md
- docs/Architecture.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `StrengthTemplate` with `TemplateCategory.run` serves as run template.
- Run templates store exercises array (legacy shape) rather than endurance fields (distance, duration, run type, etc.).
- `TemplateLibraryViewModel` and `TemplateLibraryScreen` filter by `category`.

## Scope

- Add `EnduranceTemplate` model per docs (activity type, run type, planned distance/duration, elevation, description, RPE)
- Migrate existing `StrengthTemplate` where `category == .run` to `EnduranceTemplate`
- Update `TemplateStore` protocol and file/CloudKit stores to persist both types (or unified container with discriminated union)
- Add helper: `createWorkout(from: EnduranceTemplate) -> Workout` with snapshot in `plannedValues`
- Update `TemplateLibraryViewModel` to manage endurance templates separately

## Out of Scope

- Full Templates UI refactor (Task 016) — minimal wiring only.
- Walk/trail/road activity picker in planner (Task 011).
- Weekly templates (Task 010, 017).

## Implementation Notes

Preserve existing run template IDs during migration.

`RunCategory` maps to `RunType`; add `Long Run` if missing from enum.

Bike templates use `ActivityType.bike` without run type.

## Acceptance Criteria

- The app builds.
- Existing run templates migrate to `EnduranceTemplate` without data loss.
- `createWorkout(from:)` produces independent workout with endurance planned values.
- Strength templates unaffected.

## Manual QA Checklist

- [ ] Existing run templates visible and editable.
- [ ] Apply run template to day: planned distance/type appear on workout.
- [ ] Strength templates still work.
