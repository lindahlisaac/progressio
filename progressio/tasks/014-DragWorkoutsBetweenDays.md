# 014 - Drag Workouts Between Days

## Objective

Allow users to drag workouts between days in the weekly planner.

## Required Context

Read:

- docs/PlannerUX.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Drag and drop **not implemented**.
- Skip, delete, and status toggle exist via swipe actions.
- `WeekPlannerView` uses `List` + `ForEach` for days and sessions.

## Scope

- Drag workout from one day to another within the week view
- Update `Workout.plannedDate` (or parent `DayPlan`) on drop
- If workout has completed values or `linkedHealthKitUUID`, show confirmation alert before move
- Persist change via existing week store

## Out of Scope

- Copy/paste (Task 015).
- Drag between weeks.
- Drag to reorder within same day (optional nice-to-have, not required).
- Periodized blocks.

## Implementation Notes

Use SwiftUI `.draggable` / `.dropDestination` or `onMove` patterns consistent with iOS 17+ deployment target.

Ensure dropped workout retains its stable ID (only date changes).

## Acceptance Criteria

- The app builds.
- User can drag a planned workout to another day.
- User can drag a completed workout after confirmation.
- Workout ID unchanged after move.
- Weekly totals update for both days.

## Manual QA Checklist

- [ ] Drag planned run from Monday to Wednesday.
- [ ] Drag completed run: confirmation appears, then moves.
- [ ] Drag HealthKit-linked workout: confirmation appears.
- [ ] Totals update correctly after move.
