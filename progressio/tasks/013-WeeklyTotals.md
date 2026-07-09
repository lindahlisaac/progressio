# 013 - Weekly Totals

## Objective

Move weekly totals to the top of the week planner and calculate them per modality from the new workout model.

## Required Context

Read:

- docs/PlannerUX.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Totals exist as computed properties in `WeekPlannerView` (run miles, ride miles, strength counts).
- Displayed via a **navigation link** to `WeeklyReportView`, not inline at top of week.
- Does not break out Road Run vs Trail Run vs Walk separately.

## Scope

- Add totals section at **top of week view** (above day list)
- One row per activity type **present in the selected week**
- Format: completed / planned (e.g. `Road Run: 18 / 25 mi`, `Strength: 2 / 3 sessions`)
- Road/trail/walk: prioritize distance in miles
- Bike: duration if distance unavailable, else distance
- Strength: session count
- Skipped workouts count toward planned, not completed
- Totals update on add, edit, complete, skip, delete, drag, paste

## Out of Scope

- Charts or analytics.
- History/long-term totals.
- Keep or remove `WeeklyReportView` navigation link (optional — can retain as detail drill-down).

## Implementation Notes

Extract totals calculation into a testable helper on `WeekPlan` or `WeekPlannerViewModel` to avoid duplicating logic between inline summary and report view.

## Acceptance Criteria

- The app builds.
- Totals appear at top of week planner.
- Only modalities present in the week are shown.
- Planned and completed calculated separately.
- Skipped counts as planned only.
- Totals update live when workouts change.

## Manual QA Checklist

- [ ] Week with only runs: run row appears, no bike row.
- [ ] Complete a run: completed total increases, planned unchanged.
- [ ] Skip a run: planned count includes it, completed does not.
- [ ] Delete workout: totals update.
