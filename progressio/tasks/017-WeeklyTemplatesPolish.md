# 017 - Weekly Templates Polish

## Objective

Polish weekly template UX on top of snapshot-on-apply fixes from Task 010.

## Required Context

Read:

- docs/Templates.md
- docs/Architecture.md
- docs/PlannerUX.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Weekly template list, detail, create, apply, and delete **already exist**.
- Merge/overwrite/cancel alert **already exists** when applying to non-empty week.
- `saveWeeklyTemplate` exists in view model; UI in `TemplateLibraryScreen`.
- Task 010 fixes ID collision and snapshot storage.

## Scope

Polish and verify:

- Create weekly template from currently viewed week (wire UI if missing)
- Weekly template builder supports all activity types post Task 011
- Apply to any week via planner toolbar and templates tab
- Merge / overwrite / cancel behavior per docs
- Preview shows workout summaries (strength detail on tap)
- Soft delete for weekly templates

## Out of Scope

- Periodized blocks (Tasks 024–026).
- Reimplementing apply logic (Task 010).

## Implementation Notes

This task is primarily UX polish and gap-filling after Task 010 — not a greenfield build.

## Acceptance Criteria

- The app builds.
- User can create weekly template from current week.
- User can apply to any selected week.
- Conflict prompt works: merge, overwrite, cancel.
- Strength workouts in template preview: tap for detail.
- Applied week edits do not mutate template.

## Manual QA Checklist

- [ ] Create template from current week.
- [ ] Apply to empty week.
- [ ] Apply to non-empty week: test all three conflict options.
- [ ] Edit applied week: template unchanged.
