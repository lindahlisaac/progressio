# 008 - Template Snapshot on Apply

## Objective

Fix template independence: applying a workout template must create a fully independent workout with a strength routine snapshot and stable template ID link.

## Required Context

Read:

- docs/Templates.md
- docs/Architecture.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `addTemplateSession` stores `templateName` (string) only — no `linkedWorkoutTemplateId`.
- `StrengthLogView` looks up template **by name** at view open and seeds exercises from live template if no saved log exists.
- Renaming a template breaks the link; editing template exercises affects newly opened sessions without saved logs.

## Scope

- Store `linkedWorkoutTemplateId: UUID?` on `Workout` (not name-only link)
- On template apply (`addTemplateSession`, `addStrengthSession` from template): copy strength exercises into `plannedValues.strengthRoutineSnapshot`
- `StrengthLogView` seeds from workout snapshot, not live template lookup
- Completed strength data goes into `completedValues.strengthRoutineSnapshot` (or continues file-backed with snapshot sync in Task 021)
- Editing applied workout does not mutate template
- Editing template does not mutate workouts with existing snapshots

## Out of Scope

- Endurance template split (Task 009).
- Weekly template snapshot fix (Task 010).
- Templates UI refactor (Task 016).
- Strength log CloudKit sync (Task 021).

## Implementation Notes

Snapshot should include exercise name, order, target sets/reps/weight — enough to plan and log independently.

Keep `templateName` as display-only if helpful, but ID is the canonical link.

## Acceptance Criteria

- The app builds.
- Apply strength template: workout has snapshot, new UUID, `source = template`, `linkedWorkoutTemplateId` set.
- Edit template exercises: previously applied workout unchanged.
- Edit applied workout exercises: template unchanged.
- Rename template: applied workouts still work via ID + snapshot.

## Manual QA Checklist

- [ ] Apply "Upper Push" template to Monday.
- [ ] Edit template (add exercise): Monday workout unchanged.
- [ ] Edit Monday workout (add set): template unchanged.
- [ ] Rename template: Monday workout still opens and logs correctly.
