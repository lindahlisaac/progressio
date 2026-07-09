# 011 - Planner Activity Types and Add Flow

## Objective

Update the weekly planner add-workout flow to support all target activity types per PlannerUX.

## Required Context

Read:

- docs/PlannerUX.md
- docs/ProductVision.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Add menu offers: Run, Ride, Strength, Attach detected run, Add from template.
- `SessionKind` has Run, Cycle, Strength only — no Walk, Trail Run, Road Run distinction.
- Template picker uses combined `StrengthTemplate` list.

## Scope

Refactor add-workout flow to:

1. Tap day → Add Workout
2. Choose modality: Road Run, Trail Run, Walk, Bike, Strength
3. Choose manual or template (where templates exist for that modality)
4. Save

- Update `WeekPlannerView` add menu and `WeekPlannerViewModel` add methods
- Manual add creates `Workout` with correct `ActivityType` and `source = manual`
- Template add uses helpers from Tasks 008–009
- Allow setting `timePeriod` (AM/PM) when adding a workout and when editing an existing workout (picker or segmented control in add flow and workout detail)
- Default `timePeriod` to AM when the user does not choose (required for Task 020 Apple Health matching)

## Out of Scope

- Status indicator polish (Task 012).
- Weekly totals (Task 013).
- Drag/copy/paste (Tasks 014–015).
- HealthKit import (Tasks 018–020).

## Implementation Notes

"Bike" replaces "Ride" / `Cycle` in user-facing strings.

Default new road runs to `ActivityType.roadRun` when user picks "Run" sub-type or generic run.

Keep flow fast — minimal taps per PlannerUX.

## Acceptance Criteria

- The app builds.
- User can add Road Run, Trail Run, Walk, Bike, and Strength manually to any day.
- User can add from strength or endurance template when available.
- User can set AM or PM when adding or editing a workout; unset defaults to AM.
- Week navigation unchanged.
- Existing completed values not overwritten by planned edits.

## Manual QA Checklist

- [ ] Add each activity type manually to a day.
- [ ] Add strength from template.
- [ ] Add run from endurance template.
- [ ] Edit planned values on completed workout: completed unchanged.
- [ ] Add workout with PM selected: `timePeriod` persists after save and week navigation.
- [ ] Edit existing workout: change AM → PM; value persists.
