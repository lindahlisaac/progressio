# Progressio Architecture

## Overview

Progressio should be structured around a clean separation between planning, templates, completed workout data, and imported workout data.

The core architectural principle is that reusable templates create independent workout instances. Once something has been applied to the plan, it should be safe to modify without accidentally mutating the original template.

## Core Objects

### Workout

Represents one workout on a specific day in the weekly planner.

A workout can contain both planned information and completed information.

Every workout should have:

- Stable ID
- Created timestamp
- Updated timestamp
- Activity type
- Planned values
- Completed values
- Status
- Source
- Optional linked template ID
- Optional linked HealthKit UUID

The workout itself is the object that appears on the weekly planner.

### Workout Template

A reusable blueprint for creating workouts.

Examples:

- Push workout
- Pull workout
- Leg workout
- Easy run
- Threshold run
- Long run
- Trail workout
- Bike workout
- Walk workout

Applying a workout template creates an independent workout.

Editing the resulting workout must not edit the original template.

Editing the original template must not change existing workouts that were previously created from it.

### Weekly Template

A reusable Monday-through-Sunday training schedule.

A weekly template can contain any combination of modalities.

Examples:

- Monday: 5 mile trail run AM, 45 minute bike PM
- Tuesday: strength workout
- Wednesday: easy run
- Thursday: threshold run
- Friday: off
- Saturday: long trail run
- Sunday: recovery walk

Applying a weekly template creates independent workout copies for the destination week.

### Periodized Block Template

A reusable multi-week block made from weekly templates or manually constructed weeks.

Periodized blocks support 2–12 weeks.

Each week can either:

- Use an existing weekly template
- Be manually constructed day by day

Each week has a default name:

- Week 1
- Week 2
- Week 3
- etc.

The default names can be overwritten with custom names, such as:

- Build
- Peak
- Recovery
- Race
- Deload

When a periodized block is applied to the schedule, these names should display on the corresponding weeks.

## Workout Lifecycle

A typical workflow:

1. User creates or selects a workout template.
2. User adds a workout to a day.
3. The template creates an independent planned workout.
4. User completes the workout manually or imports actual data from Apple Health.
5. Completed values are stored on the workout without deleting planned values.
6. Workout appears in history.

## Template Independence Rules

The following rules are mandatory:

- Applying a workout template creates a copy.
- Applying a weekly template creates copies.
- Applying a periodized block creates copies.
- Editing applied workouts never edits the source template.
- Editing a source template never edits previously applied workouts.
- Creating a template from an existing week creates a new independent template.

## Planned vs Completed Data

Planned data and completed data should remain distinct.

A workout may have:

- Planned distance
- Completed distance
- Planned duration
- Completed duration
- Planned strength sets/reps/weights
- Completed strength sets/reps/weights
- Planned notes
- Completion notes

Completed data should never overwrite planned data.

## Source Types

Workouts should track their source.

Supported sources:

- Manual
- Template
- Apple Health

## Workout Statuses

Supported statuses:

- Planned
- Completed
- Skipped
- Imported
- Partially Completed

## Calendar Philosophy

Planned workouts and completed workouts should live on the same calendar.

The UI should make it clear which workouts were planned and which were ad hoc/unplanned.

Completed imported workouts should be linkable to planned workouts.
