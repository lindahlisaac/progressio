# 010 - Weekly Template Snapshot on Apply

## Objective

Fix weekly template apply so it creates independent workouts with new IDs, eliminating session UUID collisions.

## Required Context

Read:

- docs/Templates.md
- docs/Architecture.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `WeeklyTemplate.days` stores `[PlannedSession]` / `[Workout]` directly.
- `applyWeeklyTemplate` copies sessions **with original IDs** — merge can create duplicate UUIDs in one week.
- Merge/overwrite/cancel UI **already exists** in `WeekPlannerView` and `WeeklyTemplateListView`.
- `saveWeeklyTemplate` copies current week sessions into template.

## Scope

- Change weekly template storage to use `WeeklyTemplateWorkoutEntry` snapshots (per docs) instead of live workout references
- On apply: generate **new UUID** for every workout created from template
- Copy full planned snapshot (strength + endurance) into each new workout
- Set `linkedWeeklyTemplateId` on applied workouts
- Merge: append new workouts alongside existing (no ID collision)
- Overwrite: soft-delete existing week workouts, then apply template copies
- Save week as template: store snapshots, not live workout references

## Out of Scope

- Periodized blocks (Tasks 024–026).
- Templates UI polish (Task 017).
- New merge/overwrite UI (already exists).

## Implementation Notes

Migrate existing `WeeklyTemplate` JSON to snapshot format in a migration step.

Template entries should store enough data to render weekly template preview without linking to live workouts.

## Acceptance Criteria

- The app builds.
- Apply weekly template to empty week: all workouts have unique IDs.
- Apply with merge: no duplicate IDs in week.
- Apply with overwrite: previous week workouts soft-deleted, new copies created.
- Edit applied workout: weekly template unchanged.
- Edit weekly template: previously applied weeks unchanged.

## Manual QA Checklist

- [ ] Apply template to empty week: 7 days populated, unique IDs.
- [ ] Apply with merge to non-empty week: both old and new workouts present, no SwiftUI ForEach ID warnings.
- [ ] Apply with overwrite: only template workouts remain.
- [ ] Cancel: no changes.
- [ ] Save current week as template, edit week, verify template unchanged.
