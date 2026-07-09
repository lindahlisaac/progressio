# 016 - Templates UI Refactor

## Objective

Refactor the existing Templates tab to manage strength and endurance templates against the new model types.

## Required Context

Read:

- docs/Templates.md
- docs/Architecture.md
- docs/PlannerUX.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- `TemplateLibraryScreen.swift` (~650 lines) already implements workout + weekly template UI.
- Segmented picker: workout templates vs weekly templates.
- Strength and run templates shown in separate sections of combined `StrengthTemplate` list.
- Create/edit/delete templates works; weekly template builder exists.
- Soft delete may not be wired in UI yet (Task 006 adds backend).

## Scope

Refactor existing UI (not greenfield) to:

- Separate strength and endurance template sections using `StrengthTemplate` + `EnduranceTemplate`
- Create/edit/delete for both template types
- Reorder strength exercises (if not already working, implement)
- Soft delete in UI (hide deleted, no hard remove)
- View template details

## Out of Scope

- Weekly templates (Task 017).
- Periodized blocks (Tasks 024–025).
- Planner add flow (Task 011).

## Implementation Notes

Preserve existing navigation structure in `ContentView` Templates tab.

Avoid rewriting entire screen — refactor in place.

## Acceptance Criteria

- The app builds.
- User can create/edit/delete strength templates.
- User can create/edit/delete endurance templates (road, trail, walk, bike).
- Strength exercise reorder works.
- Editing template does not affect previously applied workouts.
- Deleted templates use soft delete.

## Manual QA Checklist

- [ ] Create strength template with 3 exercises.
- [ ] Reorder exercises.
- [ ] Create endurance template with distance and run type.
- [ ] Delete template: disappears from list.
- [ ] Applied workout from template unchanged after template edit.
