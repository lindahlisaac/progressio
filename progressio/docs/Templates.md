# Progressio Templates

## Template Philosophy

Templates are designed to reduce repetitive workout planning.

Templates are blueprints only.

Once a template is applied to a week or day, the resulting workout is independent from the template.

Editing the applied workout must not change the original template.

Editing the original template must not change workouts that have already been created from it.

## Template Types

Progressio supports multiple template types:

- Strength templates
- Endurance workout templates
- Weekly templates
- Periodized block templates

## Strength Templates

Strength training routines should exist as their own type of template.

Example strength templates:

- Push Day
- Pull Day
- Leg Day

When adding a strength training workout to the plan, the user should be able to select a specific strength template as the base for the workout.

Once applied, the workout can be edited independently.

The original strength template can only be edited from the Templates section.

### Strength Template Characteristics

A strength template includes:

- Template name
- Exercises
- Exercise order
- Sets
- Target reps
- Target weight optional
- Notes
- Muscle group/category optional

### Strength Template Workflow

1. User opens Templates.
2. User creates or edits a strength template.
3. User opens Plan.
4. User taps a day.
5. User chooses Add Workout.
6. User chooses Strength.
7. User selects Push, Pull, Leg, or another strength template.
8. A workout is created from the template.
9. User later opens the workout and fills in completed values.
10. User completes the workout.
11. The original template remains unchanged.

## Endurance Templates

Endurance templates are used for:

- Road Run
- Trail Run
- Walk
- Bike

### Endurance Template Structure

Fields:

- Activity type
- Run type
- Planned distance
- Planned duration optional
- Elevation gain optional, especially for trail
- Description/freeform structure
- Intensity/RPE optional
- Route optional later

### Run Types

Supported run types:

- Easy
- Recovery
- Tempo
- Threshold
- VO2
- Long Run
- Race

### Freeform Structure

The description field can be used to describe workout structure.

Examples:

- 2 mile warmup, 6 x 3 minutes hard / 2 minutes easy, 2 mile cooldown
- 8 mile easy trail run, conversational effort
- 3 x 10 minutes threshold with 3 minutes jog recovery

This can remain freeform for now.

## Weekly Templates

A weekly template is a reusable Monday-through-Sunday training structure.

It can combine any modalities.

Example:

- Monday AM: 5 mile trail run
- Monday PM: 45 minute bike
- Tuesday: Push strength
- Wednesday: Easy road run
- Thursday: Threshold workout
- Friday: Rest
- Saturday: Long trail run
- Sunday: Recovery walk

### Applying a Weekly Template

When applying a weekly template to a week, if there is an existing workout anywhere in that week, the user must be asked whether to:

- Merge the template into the week
- Overwrite pre-existing workouts for that week
- Cancel

### Merge Behavior

Merge should add the template workouts to the week while preserving existing workouts.

### Overwrite Behavior

Overwrite should remove or soft-delete existing workouts for the week and replace them with workouts created from the template.

### Cancel Behavior

Cancel should make no changes.

### Creating a Weekly Template from a Week

When viewing a week, the user should be able to create a weekly template from that week.

This is useful when the user liked the structure of a week and wants to repeat it.

The created template should be independent from the source week.

Future edits to the week should not change the template.

Future edits to the template should not change the original week.

## Strength Workouts Inside Weekly Templates

Weekly templates should display that there is a strength workout on a day.

The basic weekly template view does not need to display all routine details inline.

The strength workout itself can be tapped to view the detailed strength routine.

## Periodized Block Templates

A periodized block is a template of templates.

Users should be able to create a periodized block ranging from 2 to 12 weeks.

Each week of the block can be built using:

- A weekly template
- Manual day-by-day construction

The completed periodized block can then be saved as a periodized block template.

### Applying a Periodized Block

When applying a periodized block to the schedule, the user selects the beginning week.

The application should detect whether any existing workouts would be overwritten in the entire date range.

If conflicts exist, the user must be notified before anything is applied.

The user should be given conflict options similar to weekly template application.

### Periodized Block Week Names

By default each week should be named:

- Week 1
- Week 2
- Week N

These default names can be overwritten.

Example custom names:

- Build
- Peak
- Recovery
- Deload

When a periodized block is applied, the week names should display in the planner.
