# 020 - Apple Health Planned Matching

## Objective

When importing a HealthKit workout, match to a planned workout by activity type and AM/PM period, and prompt the user before applying.

## Required Context

Read:

- docs/AppleHealth.md
- docs/PlannerUX.md
- docs/DataModel.md
- tasks/ImplementationNotes.md
- tasks/019-AppleHealthUUIDDedup.md

## Current State (from audit)

- No automatic match prompt.
- `timePeriod` is user-settable in planner UI after Task 011; defaults to AM from migration (Task 004) when unset.
- `attachActualRun` fills `actualRun` / completed values and sets status completed without confirmation when user picks session.

## Scope

On import of each new HealthKit workout:

1. Determine activity type and date
2. Determine AM/PM from workout start time (centralized helper):
   - AM = 12:00 AM – 11:59 AM
   - PM = 12:00 PM – 11:59 PM
3. Search planned workouts on same day with same activity type and time period
4. If likely match: prompt user to apply to planned workout or create ad hoc
5. If accepted: fill `completedValues`, preserve `plannedValues`, set `linkedHealthKitUUID`, update status
6. If declined: create imported ad-hoc workout

Replace or augment manual-only attach flow for automatic imports; keep manual attach as fallback.

## Out of Scope

- Fuzzy matching beyond activity + day + AM/PM.
- AI suggestions.
- Bike/walk HK import (unless already in pipeline from Task 019).

## Implementation Notes

Centralize AM/PM logic in one utility (e.g. `TimePeriod.from(date:)`).

Matching runs before adding to unattached list reduces user steps.

## Acceptance Criteria

- The app builds.
- Import prompts when planned workout matches activity + day + period.
- Accept: planned preserved, completed filled, UUID linked.
- Decline: new imported workout created.
- No automatic overwrite without user confirmation.

## Manual QA Checklist

- [ ] Planned AM run + AM HK import: prompt appears.
- [ ] Accept: planned distance unchanged, actual distance filled.
- [ ] Decline: ad-hoc imported workout on calendar.
- [ ] PM import does not match AM planned workout without prompt.
