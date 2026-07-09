# 024 - Periodized Block Models

## Objective

Implement persisted models for 2–12 week periodized block templates.

## Required Context

Read:

- docs/Architecture.md
- docs/Templates.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Periodized blocks **not implemented**.
- Weekly templates exist and will use snapshot format after Task 010.

## Scope

Add models:

- `PeriodizedBlockTemplate` — id, metadata, name, weekCount (2–12), weeks, notes
- `PeriodizedBlockWeek` — weekIndex, displayName, linkedWeeklyTemplateId or manuallyConstructedWeek

Persist and sync via JSON + CloudKit (new record type).

Default week names: Week 1, Week 2, … Custom names supported.

## Out of Scope

- UI (Task 025).
- Apply to calendar (Task 026).

## Implementation Notes

Follow metadata patterns from Task 006 (timestamps, soft delete, schema version).

Weeks reference weekly template snapshots or inline week snapshots — not live planner data.

## Acceptance Criteria

- The app builds.
- Models persist locally and sync to CloudKit.
- Week count constrained to 2–12.
- Default and custom week names work.

## Manual QA Checklist

- [ ] Create block programmatically or via minimal test hook: saves and loads.
- [ ] Sync block to CloudKit (if testable).
