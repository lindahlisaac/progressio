# Progressio Product Vision

## Purpose

Progressio is a training planning application designed for multi-modal endurance athletes. Unlike a workout tracker whose primary purpose is recording completed activities, Progressio is built around planning training first and recording execution second.

The weekly planner is the heart of the application.

The application should make it extremely fast to build and modify training plans while still allowing completed workouts to be tracked and imported from Apple Health.

The design philosophy is minimalist, fast, and highly reusable through templates.

## Primary Modalities

- Road Running
- Trail Running
- Cycling
- Walking
- Strength Training

Future modalities should be easy to add without significant architectural changes.

## Core Philosophy

- Planning comes before tracking.
- The weekly planner should always be the primary screen.
- Adding a workout should require as few interactions as possible.
- Anything repetitive should become reusable through templates.
- Completed workouts should never overwrite planned workouts.
- Templates should never change workouts that have already been created from them.
- The application should feel like a serious training planning tool rather than a generic fitness tracker.

## Primary Navigation

- Plan
- Templates
- History
- Settings

## Development Roadmap

### Phase 1 — Data Model Cleanup

- Stable IDs
- Schema versioning
- Workout/template/planned/completed separation
- Migration from current models to new models
- iCloud-safe syncing

### Phase 2 — Weekly Planner Polish

- Fast week view
- Add workout flow
- Drag/drop
- Copy/paste
- Skipped state
- Weekly totals

### Phase 3 — Templates

- Strength templates
- Run templates
- Bike templates
- Walk templates
- Weekly templates
- Create template from existing week

### Phase 4 — Apple Health Import

- Deduplication
- Matching to planned workouts
- User confirmation
- Imported/ad hoc indicators

### Phase 5 — Periodized Blocks

- 2–12 week training blocks
- Built from weekly templates or manual construction
- Apply blocks to the calendar starting from a selected week
- Detect conflicts before applying
