# Progressio Planner UX

## Weekly Planner

The weekly planner is the primary screen of the application.

The user should be able to view a Monday-through-Sunday schedule and plan workouts for each day of the week.

The planner should support multiple workouts per day.

Example:

- Monday AM: 5 mile trail run
- Monday PM: 45 minute cycle

## Primary Add Workout Flow

The core interaction should be extremely fast:

1. Tap day
2. Add Workout
3. Choose modality
4. Choose manual or template
5. Save

## Supported Workout Types

- Road Run
- Trail Run
- Walk
- Bike
- Strength

## Weekly Totals

The weekly totals section appears at the top of the week view.

It should show completed values out of planned values.

The section should display one row for each workout type included in the given week.

Examples:

- Road Run: 18 / 25 miles
- Trail Run: 6 / 10 miles
- Bike: 45 / 90 minutes
- Strength: 2 / 3 sessions
- Walk: 4 / 5 miles

Strength should be counted by number of completed sessions out of planned sessions.

Endurance activities should generally be counted by miles where applicable.

Cycling may use duration or distance depending on available data and current app conventions.

## Planned vs Completed Display

Planned and completed workouts should live on the same calendar.

The UI should clearly display in a minimal fashion which workouts were:

- Planned
- Completed
- Imported
- Ad hoc/unplanned
- Skipped

Ad hoc workouts are workouts that were not originally planned but were added from import or manual entry.

## Drag and Drop

Users should be able to drag workouts between days.

This supports cases where:

- The user added a workout to the wrong day
- The user needs to modify the week because of a scheduling conflict
- The user wants to rearrange training

If a workout already contains completed values or imported HealthKit data, the app should confirm before moving it.

## Copy and Paste

Users should be able to copy workouts.

Workflow:

1. User long presses a workout.
2. User chooses Copy.
3. User selects a different day.
4. User chooses Paste.
5. User is prompted to paste either:
   - Planned values only
   - Planned and completed values

Use case:

If a user liked a workout from the previous week, they should be able to go back to that week, copy the workout, and paste it onto a different day.

Copied workouts must receive new IDs.

Copied workouts must not maintain a live link to the original workout.

## Skipped Workouts

Users should be able to mark workouts as skipped.

Skipped workouts should remain visible in the planner.

Skipped workouts should display a small indicator/bubble showing that they were skipped.

When a workout is skipped, the user should be prompted to provide an optional reason why they skipped it.

## Template Application UX

When applying a weekly template to a week, if the week already contains at least one workout, show options:

- Merge
- Overwrite
- Cancel

When applying a periodized block, conflict detection should occur across the entire date range before applying any workouts.

## Create Template from Week

When viewing a week, the user should have a way to create a weekly template from the currently viewed week.

This supports saving a week structure that the user liked and wants to repeat.

The new template must be independent from the source week.
