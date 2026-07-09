# 012 - Planner Status Indicators

## Objective

Improve minimal visual distinction between planned, completed, imported, and skipped workouts on the week planner.

## Required Context

Read:

- docs/PlannerUX.md
- docs/Architecture.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `SessionRow` shows status badge (Planned, Completed, Unplanned, Skipped) with color tints.
- Skip workflow **already implemented** (swipe → skip, optional note sheet).
- `PlanStatus.unplanned` used for ad-hoc/imported; target uses `WorkoutStatus.imported`.
- No distinct indicator for partially completed workouts.

## Scope

- Map UI to `WorkoutStatus`: Planned, Completed, Skipped, Imported, Partially Completed
- Minimal visual indicators per PlannerUX (badge/chip, not noisy)
- Imported/ad-hoc workouts clearly distinguishable from planned-not-yet-done
- Partially completed state visible when some but not all completed values present
- Verify skip flow still works after model migration (no reimplementation)

## Out of Scope

- Weekly totals (Task 013).
- Drag/copy/paste (Tasks 014–015).
- HealthKit matching UI (Task 020).

## Implementation Notes

Reuse existing `SessionRow` patterns — refine, don't redesign.

`Imported` replaces `unplanned` in display strings.

## Acceptance Criteria

- The app builds.
- Each status has a distinct minimal indicator.
- Skipped workouts remain visible with skipped indicator and optional reason.
- Imported workouts distinguishable from planned.
- Partially completed workouts show appropriate state.

## Manual QA Checklist

- [ ] Planned workout: shows planned indicator.
- [ ] Completed workout: shows completed indicator.
- [ ] Skipped workout: visible with skip note.
- [ ] Imported/ad-hoc workout: shows imported indicator.
- [ ] Partial completion (e.g. distance only): shows partially completed.
