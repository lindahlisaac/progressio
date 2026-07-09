# Progressio Data Model

## Data Model Principles

All records should support:

- Stable IDs
- Schema versioning
- Migration
- iCloud synchronization
- Cloud conflict handling
- Soft deletes or tombstones
- Created timestamps
- Updated timestamps
- Source tracking

This is one of the most important engineering concerns for the app.

## Stable IDs

Every persistent object should have a stable unique identifier.

Objects that need stable IDs include:

- Workout
- WorkoutTemplate
- StrengthTemplate
- EnduranceTemplate
- WeeklyTemplate
- PeriodizedBlockTemplate
- ExerciseTemplate
- CompletedSet
- ImportedHealthWorkoutReference

## Schema Versioning

The data model should include a schema versioning mechanism so the app can safely migrate old user data as the model evolves.

Migration must be handled carefully because the app already has existing infrastructure and user data.

## Soft Deletes / Tombstones

For iCloud-safe syncing, records should avoid immediate hard deletes where this could cause sync conflicts.

Deleted records should support a tombstone/soft-delete state where appropriate.

Possible fields:

- isDeleted
- deletedAt
- updatedAt

## Workout

A workout represents one planned or completed training session on a specific calendar day.

Suggested fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- plannedDate
- timePeriod
- activityType
- runType optional
- plannedValues
- completedValues
- status
- source
- linkedWorkoutTemplateId optional
- linkedWeeklyTemplateId optional
- linkedPeriodizedBlockId optional
- linkedHealthKitUUID optional
- notes optional
- skipReason optional

## Time Period

Used for planning and Apple Health matching.

Suggested values:

- AM
- PM

The app should define exact cutoff rules.

Suggested default:

- AM: 12:00am through 11:59am
- PM: 12:00pm through 11:59pm

## Activity Type

Supported values:

- Road Run
- Trail Run
- Walk
- Bike
- Strength

## Run Type

Supported values:

- Easy
- Recovery
- Tempo
- Threshold
- VO2
- Long Run
- Race

## Workout Status

Supported values:

- Planned
- Completed
- Skipped
- Imported
- Partially Completed

## Workout Source

Supported values:

- Manual
- Template
- Apple Health

## Planned Values

A workout should preserve planned values separately from completed values.

Possible planned fields:

- plannedDistance
- plannedDuration
- plannedElevationGain
- plannedIntensityRPE
- plannedDescription
- plannedRoute optional
- plannedStrengthRoutineSnapshot optional

## Completed Values

Possible completed fields:

- completedDistance
- completedDuration
- completedElevationGain
- completedIntensityRPE
- completedCalories optional
- completedHeartRateAverage optional
- completedHeartRateMax optional
- completedDescription
- completedStrengthRoutineSnapshot optional
- completedAt

## Workout Template

A general reusable workout blueprint.

Suggested fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- name
- activityType
- templateKind
- source
- notes optional

## Strength Template

Fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- templateName
- exercises
- notes optional

## Strength Exercise Template

Fields:

- id
- name
- orderIndex
- targetSets
- targetReps
- targetWeight optional
- notes optional
- muscleGroup optional

## Strength Workout Snapshot

When a strength template is applied to a workout, the workout should store a snapshot/copy of the routine.

This allows the workout to be edited without modifying the original template.

Fields:

- exercises
- completedSets optional
- completionNotes optional

## Completed Strength Set

Fields:

- id
- exerciseId
- setNumber
- actualReps
- actualWeight optional
- notes optional

## Endurance Template

Used for road run, trail run, walk, and bike templates.

Fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- templateName
- activityType
- runType optional
- plannedDistance
- plannedDuration optional
- plannedElevationGain optional
- description optional
- intensityRPE optional
- route optional/future

## Weekly Template

A reusable Monday-through-Sunday schedule.

Fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- name
- days
- notes optional

Each day contains zero or more template workout entries.

## Weekly Template Day

Fields:

- weekday
- workoutEntries

## Weekly Template Workout Entry

Fields:

- id
- dayOfWeek
- timePeriod
- activityType
- linkedTemplateId optional
- workoutSnapshot

The weekly template can display a basic summary of strength workouts. The details should be viewable by tapping the strength workout.

## Periodized Block Template

Fields:

- id
- schemaVersion
- createdAt
- updatedAt
- deletedAt optional
- isDeleted
- name
- weekCount
- weeks
- notes optional

## Periodized Block Week

Fields:

- weekIndex
- displayName
- linkedWeeklyTemplateId optional
- manuallyConstructedWeek optional

Default display names:

- Week 1
- Week 2
- Week N

Custom display names may include:

- Build
- Peak
- Recovery
- Race

## HealthKit Reference

Imported workouts should preserve HealthKit identity.

Fields:

- id
- healthKitUUID
- workoutId
- importedAt
- source

If the same HealthKit UUID already exists locally, the workout must not be imported again.
