# Progressio Apple Health Integration

## Purpose

Progressio should import workouts from Apple Health while preserving the planning workflow.

Imported workouts should fill actual/completed values when they correspond to a planned workout.

If an imported workout does not correspond to a planned workout or the user chooses not to link it, it should become a new ad hoc workout.

## Current Problem

The app already has infrastructure to pull workouts from Apple Health, but the import is bugged and workouts are being duplicated/imported multiple times.

The new implementation must prevent duplicate imports.

## Deduplication Rule

Every imported Apple Health workout should store the original Apple Health workout UUID.

If a workout with the same HealthKit UUID already exists locally, do not import it again.

This should be the primary duplicate protection mechanism.

## Fallback Duplicate Detection

If HealthKit UUID matching is unavailable for any reason, fallback duplicate detection may compare:

- Start date
- End date
- Activity type
- Duration
- Distance

This fallback should be used carefully and should not replace UUID-based deduplication.

## Import Matching Workflow

When a workout is imported from Apple Health:

1. Determine the workout's activity type.
2. Determine the workout's date.
3. Determine whether it belongs to the AM or PM period.
4. Search the current day in the weekly plan.
5. Look for an existing workout of the same type in the same AM/PM period.
6. If a likely match exists, ask the user whether they want to apply the imported workout to the planned workout.
7. If the user accepts, fill the completed/actual values on the existing planned workout.
8. If the user declines, create a new workout based on the imported data.

## AM/PM Matching

The app should define exact AM/PM cutoff rules.

Suggested default:

- AM: 12:00am through 11:59am
- PM: 12:00pm through 11:59pm

## Applying Imported Data to Planned Workout

If the user chooses to apply the imported workout to a planned workout:

- Preserve the planned values.
- Populate completed values from Apple Health.
- Set or update linked HealthKit UUID.
- Set source or completed source to Apple Health.
- Mark workout as completed or partially completed as appropriate.

## Creating New Ad Hoc Workout

If the user chooses not to apply the imported workout to an existing workout:

- Create a new workout.
- Populate the workout from Apple Health data.
- Mark it as imported/ad hoc.
- Store HealthKit UUID.
- Display it on the same calendar as planned workouts.

## Imported/Ad Hoc Indicators

The planner UI should clearly indicate, in a minimal way, which workouts were imported and which workouts were ad hoc/unplanned.

## Import Safety

Import should be idempotent.

Running the import process multiple times should not create duplicate workouts.

HealthKit import should not delete planned workouts.

HealthKit import should not overwrite planned values.
