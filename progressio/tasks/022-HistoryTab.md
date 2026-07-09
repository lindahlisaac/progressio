# 022 - History Tab

## Objective

Add a History tab showing completed and imported workouts in a minimal list.

## Required Context

Read:

- docs/ProductVision.md
- docs/PlannerUX.md
- docs/AppleHealth.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Navigation: Week, Templates, Settings — **no History tab**.
- Completed workouts only visible on week planner and `WeeklyReportView`.
- No cross-week completed workout list.

## Scope

- Add History tab to `ContentView` per ProductVision navigation: Plan → Templates → History → Settings
- List completed, imported, and partially completed workouts across weeks (reverse chronological)
- Minimal row: date, activity type, title/summary, status
- Tap for detail (reuse run/strength detail views where possible)
- Hide soft-deleted workouts

## Out of Scope

- Advanced analytics or charts.
- Export/import (Task 023).
- Settings sync controls.

## Implementation Notes

Query across week plan files or maintain a lightweight index — avoid loading all weeks eagerly on launch if possible.

Rename Week tab to "Plan" in tab label if aligning with ProductVision (optional).

## Acceptance Criteria

- The app builds.
- History tab appears in navigation.
- Completed workouts from multiple weeks appear in list.
- Imported ad-hoc workouts appear.
- Tapping entry opens appropriate detail view.

## Manual QA Checklist

- [ ] Complete workouts in two different weeks: both appear in History.
- [ ] Imported ad-hoc workout appears.
- [ ] Skipped-only workouts do not appear (or appear only if docs require — default: completed/imported only).
- [ ] Soft-deleted workouts hidden.
