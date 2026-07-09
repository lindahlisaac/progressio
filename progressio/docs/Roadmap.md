# Progressio Roadmap

## Phase 1 — Data Model Cleanup

Goal: create a stable foundation for future development.

Scope:

- Stable IDs
- Schema versioning
- Workout/template/planned/completed separation
- Migration from current models to new models
- iCloud-safe syncing
- Soft deletes/tombstones
- Created/updated timestamps
- Source fields

Success criteria:

- Existing data can migrate safely.
- Workouts have separate planned and completed values.
- Templates can create independent workout copies.
- Cloud sync remains functional.

## Phase 2 — Weekly Planner Polish

Goal: make the weekly planner fast, intuitive, and useful as the primary screen.

Scope:

- Fast week view
- Add workout flow
- Drag/drop workouts between days
- Copy/paste workouts
- Skipped state with optional reason
- Weekly totals
- Planned/completed/ad hoc indicators

Success criteria:

- User can plan an entire week quickly.
- User can modify the week without friction.
- Weekly totals show completed out of planned values.

## Phase 3 — Templates

Goal: make repetitive training structures reusable.

Scope:

- Strength templates
- Run templates
- Bike templates
- Walk templates
- Weekly templates
- Create template from existing week

Success criteria:

- User can create reusable strength routines.
- User can create reusable endurance workouts.
- User can create and apply weekly templates.
- Applied templates do not maintain destructive links to source templates.

## Phase 4 — Apple Health Import

Goal: reliably import completed workouts without duplicating or damaging planned data.

Scope:

- HealthKit UUID deduplication
- Matching imports to planned workouts
- User confirmation before applying imports
- Create ad hoc workouts when needed
- Imported/ad hoc indicators

Success criteria:

- Running import repeatedly does not duplicate workouts.
- Imported workouts can fill completed values on planned workouts.
- Declined matches become ad hoc imported workouts.

## Phase 5 — Periodized Blocks

Goal: allow users to build and apply multi-week training plans.

Scope:

- 2–12 week periodized blocks
- Build from weekly templates
- Manually construct weeks
- Save periodized block templates
- Apply block starting from a selected week
- Detect conflicts across the full block range
- Show week names in planner

Success criteria:

- User can build a multi-week block.
- User can apply the block safely to the planner.
- Existing workouts are not overwritten without explicit confirmation.
