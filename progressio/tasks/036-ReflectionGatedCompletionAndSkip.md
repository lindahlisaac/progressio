# 036 - Reflection-Gated Completion and Skip Reflections

## Objective

Change completion so a workout is **not** marked `.completed` until an activity reflection is **saved**. On **skip**, present a **light** skip reflection (reason + optional injury/discomfort), not the full performance reflection.

## Decisions (locked — see `NEXT-FEATURES-QUESTIONS.md`)

- Complete: status stays non-complete until reflection **Save**; dismiss = not complete.
- Skip: **lighter** form (reason + optional injury link), not full feel/sessionRPE form.
- Prefer: light skip sheet is part of finalizing skip (Save finalizes `.skipped`).

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md`
- `tasks/029-subj-data-impl` (prior “optional reflection” — **superseded for completion**)
- `Views/WeekPlanner/ActivityReflectionSheet.swift`
- `Views/WeekPlanner/WeekPlannerView.swift` (`requestActivityReflection`)
- `Views/WeekPlanner/WeekPlannerTemplatePresentations.swift` (skip sheet)
- `ViewModels/WeekPlannerViewModel+Reflections.swift`
- `Models/ReflectionModels.swift`

## Current State

- Status set to `.completed` **before** reflection sheet; sheet Skip leaves workout completed.
- Skip sets `.skipped` + optional `skipReason`; no reflection / injury update path.
- History excludes skips.

## Scope

### A. Gate completion on reflection save

1. Refactor complete paths (swipe, strength/run/ride/StairMaster detail, HK attach/match accept):
   - Do **not** write `.completed` until reflection Save (or explicit keep of existing reflection on re-complete).
2. Full `ActivityReflectionSheet` on complete paths:
   - **Save** → persist reflection → set `.completed` (+ completedAt / strength lock as today).
   - **Dismiss** → leave prior status; no complete.
   - Remove the old sheet control that completed without saving a reflection.
3. Re-complete: overwrite-vs-keep retained; still only `.completed` after Save or Keep.
4. Docs: reflections **required to complete**; weekly reflection remains optional for week close.

### B. Light reflection on skip

1. After skip is initiated, show a **compact** sheet:
   - Skip reason (can merge with existing skip-reason UI into one step)
   - Optional physical discomfort / link-or-create `PhysicalIssue` (reuse discomfort controls lightly)
   - **No** full feel + session RPE + performance notes requirement
2. Persist:
   - Workout: `.skipped`, `skipReason`
   - Optional: a minimal `ActivityReflection` **or** only issue report + skipReason — prefer a small reflection record if it keeps History/export consistent; otherwise document skipReason + optional `ActivityIssueReport` without full reflection. **Recommendation:** save a slim `ActivityReflection` with defaults/placeholder feel only if the model requires non-optional feel — if so, extend model with optional fields or a `reflectionKind: standard | skip` rather than faking RPE. Pick the cleanest approach; avoid fake RPE data.
3. History: show skipped workouts that have skip context (badge **Skipped**), or at least ensure Injury hub sees skip-linked issues (037). Prefer History inclusion with Skipped badge.

### C. Tests

- Complete path does not flip to `.completed` without saved reflection.
- Skip finalize persists reason and optional issue link.

## Out of Scope

- Mandatory weekly reflection for week close
- Injury hub UI (037)
- Changing reflection scale enums beyond what’s needed for skip kind

## Implementation Notes

- Single `beginComplete(workoutID:)` → sheet → `finalizeComplete` so paths cannot diverge.
- Strength Complete must not lock as completed until reflection Save.
- Soft edit warning for History stays in 038.

## Acceptance Criteria

- [ ] No complete path leaves `.completed` without saved (or kept) activity reflection.
- [ ] Dismissing complete reflection leaves workout not completed.
- [ ] Skip uses light sheet (reason + optional injury); not full performance form.
- [ ] Docs supersede 029 optional-on-complete.
- [ ] App builds.

## Manual QA Checklist

- [ ] Swipe complete → dismiss sheet → still Planned.
- [ ] Save reflection → Completed.
- [ ] Strength / HK complete → same gate.
- [ ] Skip → light sheet → reason + optional injury → Skipped persisted.
