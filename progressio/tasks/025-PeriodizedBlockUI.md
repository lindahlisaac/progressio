# 025 - Periodized Block UI

## Objective

Build Templates UI for creating and editing periodized blocks.

## Required Context

Read:

- docs/Templates.md
- docs/Architecture.md
- docs/PlannerUX.md
- tasks/024-PeriodizedBlockModels.md

## Current State (from audit)

- Templates tab has workout + weekly template sections.
- No periodized block UI.

## Scope

In Templates section:

- Create periodized block (length 2–12)
- Each week: link existing weekly template **or** manual day-by-day construction
- Rename weeks (default Week 1…N; custom Build, Peak, Recovery, etc.)
- Edit and soft-delete blocks

## Out of Scope

- Apply to planner calendar (Task 026).

## Implementation Notes

Reuse weekly template picker and builder components from Task 017 where possible.

## Acceptance Criteria

- The app builds.
- User can create and edit periodized blocks.
- User can configure each week via template link or manual build.
- User can rename weeks.
- Blocks persist and sync.

## Manual QA Checklist

- [ ] Create 4-week block with mixed weekly template links.
- [ ] Rename week 3 to "Peak".
- [ ] Edit block: changes saved.
- [ ] Delete block: soft-deleted, hidden from list.
