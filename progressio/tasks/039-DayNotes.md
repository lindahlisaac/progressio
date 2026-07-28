# 039 - Per-Day Notes

## Objective

Add an expandable notes field on each planner day for freeform journaling of what happened that day (independent of individual workout notes).

## Decisions (locked — see `NEXT-FEATURES-QUESTIONS.md`)

- One notes field **per day** (not AM/PM).
- UI: collapsible disclosure/chevron attached to the day — discrete, not hidden, not always-open.

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md`
- `Models/Models.swift` (`DayPlan`, `WeekPlan`)
- `Views/WeekPlanner/WeekPlannerView.swift`
- Sync: day notes must ride inside existing WeekPlan JSON/CloudKit blob

## Current State

- `DayPlan`: id, date, workouts, updatedAt, etag — **no notes**.
- Notes exist only on `Workout.notes` / `skipReason`.

## Scope

1. Add `notes: String?` (or `dayNotes`) to `DayPlan` with `decodeIfPresent` default nil.
2. Planner UI: disclosure group / chevron under the day header. Collapsed by default when empty; when non-empty, collapsed preview line + expand to edit. Always visible as a discrete control (not buried in a menu).
3. Persist via existing `persistWeek` / week updatedAt stamping.
4. Include day notes in week export JSON automatically (Codable). Optionally mention in `WeekExportSummary` text export if easy.
5. Docs: DataModel + ImplementationNotes.

## Out of Scope

- Rich text / attachments
- Separate CloudKit type for notes
- AM/PM split notes

## Acceptance Criteria

- [ ] User can add/edit notes on a day; survives relaunch and sync.
- [ ] Old weeks without the field still load.
- [ ] UI is expandable and doesn’t clutter empty days.
- [ ] App builds.

## Manual QA Checklist

- [ ] Write Monday notes → leave week → return → notes present.
- [ ] Force sync / second device (if available) → notes present.
- [ ] Expand/collapse behavior feels light.
