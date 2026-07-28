# 035 - Strength Session Summary and Export

## Objective

After completing a strength session, show a basic summary (total sets, reps, etc.). Add a 3-dot menu to export the session as readable text (grouped lift list) and as JSON (lifts / weights / reps) for sharing or future coach workflows.

## Decisions (locked — see `NEXT-FEATURES-QUESTIONS.md`)

- Text export header = **workout title** (no special program-section grouping).
- JSON **import** = out of scope (export only).

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md`
- `Views/WeekPlanner/StrengthLogView.swift`
- `Models/WorkoutValues.swift` (snapshots; include `isSkipped` from 034)
- `ViewModels/WeekPlannerViewModel.swift` (week export patterns)
- Task 034 should land first so exports respect skipped sets

## Current State

- Complete locks the UI and triggers reflection; no post-complete summary.
- No per-session text or JSON export from strength UI.
- Week JSON export already embeds full snapshots (coarse, whole week).

## Scope

1. **Completion summary (basic):** When marking complete (or on locked completed view), show totals such as:
   - Exercises count
   - Sets logged (exclude skipped; decide whether empty counts)
   - Total reps (sum of parsed actual reps)
   - Optional: total volume (weight × reps) when weights parse cleanly
2. **Toolbar 3-dot menu** on StrengthLogView (completed and/or anytime snapshot exists):
   - **Copy / Share text** — header is workout title, then lines like `Machine Chest Press – 4 sets`. Count only non-skipped sets that have logged work (has weight or reps). Document the rule.
   - **Export JSON** — share/save a file with session id, title, date, exercises[], sets[{setNumber, weight, reps, isSkipped, targetReps, …}]. Stable schema; `formatVersion: 1`.
3. Coach JSON **import**: explicitly out of scope; note in ImplementationNotes that export enables a future import.
4. Skipped sets: appear in JSON with `isSkipped: true`; annotate in text export (e.g. “3 sets (1 skipped)”).

## Out of Scope

- JSON / coach import
- Full coach program builder
- Changing week-level export format beyond what’s needed
- Reflection gating (036)

## Acceptance Criteria

- [ ] Completed strength session shows a basic numeric summary.
- [ ] Share sheet / export produces text in the requested style.
- [ ] JSON export file contains lifts, weights, reps, skip flags.
- [ ] App builds.

## Manual QA Checklist

- [ ] Complete a session → summary numbers look right vs manual count.
- [ ] 3-dot → text export matches lifts/set counts.
- [ ] 3-dot → JSON opens and matches the logged snapshot.
- [ ] Skipped sets handled per documented rule.
