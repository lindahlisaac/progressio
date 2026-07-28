# 041 - Replace Workout with Reason (Substitution History)

## Objective

Allow **replacing** a planned workout with a different activity instead of delete+re-add, capturing a reason and preserving history for trend analysis (e.g. many run→bike substitutions during an injury block vs skips).

## Decisions (locked)

- Soft-delete the original, link ids (`replacedWorkoutId` / `replacedByWorkoutId`), store `replacementReason`.

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md` (replace = soft-delete original + link + reason — locked)
- `Models/Workout.swift`, `Models/WorkoutEnums.swift`
- `ViewModels/WeekPlannerViewModel.swift` (`removeWorkout`, `moveWorkout`, copy/paste)
- `docs/DataModel.md`
- Reflections / PhysicalIssue links (replaced workout may still have reports)

## Current State

- Soft-delete, move, copy/paste, template override exist.
- **No** replace/substitution concept; delete loses planning narrative.

## Scope

1. **Model** (prefer minimal fields on `Workout`, all optional + decodeIfPresent):
   - `replacedWorkoutId: UUID?` — new workout points at prior
   - `replacedByWorkoutId: UUID?` — on the soft-deleted prior (optional but useful)
   - `replacementReason: String?` — why substituted
   - Optional `WorkoutSource.substituted` or keep `manual` + reason only — pick one; document.
2. Soft-delete (or status) the **original** so it leaves the active day list but remains in week JSON for analysis/export.
3. **UI:** action on workout row/menu — “Replace…” → reason prompt → activity picker / template picker → creates new workout on same day/timePeriod by default.
4. Export / week summary: note substitutions (count or lines) when reason present.
5. Future-friendly: History or Injury hub can later count substitutions; v1 at least persists links + reason.
6. Docs + DataModel.puml soft-link.

## Out of Scope

- Full analytics dashboard of substitution rates (persist data only)
- Multi-workout bulk replace
- Automatically suggesting bike when hip injury flagged

## Implementation Notes

- Do not break week-close unresolved rules: replaced original should not count as open planned work (soft-deleted / excluded like other soft-deletes).
- If original had a reflection, leave it attached to original id; new workout gets its own completion/reflection lifecycle.
- Cascade policies from 030: replacing ≠ deleting for injury reports on the old id — keep old reports on old workout.

## Acceptance Criteria

- [ ] User can replace a workout with reason; new workout appears; old retained soft-deleted/linked.
- [ ] Reason and ids persist in week JSON / sync.
- [ ] Unresolved week-close ignores the replaced original.
- [ ] Docs updated.
- [ ] App builds.

## Manual QA Checklist

- [ ] Replace run → bike with reason “hip flare” → day shows bike; export/JSON has link + reason.
- [ ] Complete new workout normally.
- [ ] Soft-deleted original not shown as active planned row.
- [ ] Force sync preserves substitution metadata.
