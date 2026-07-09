# 026 - Apply Periodized Blocks

## Objective

Allow users to apply a periodized block to the calendar starting at a selected week.

## Required Context

Read:

- docs/Templates.md
- docs/PlannerUX.md
- docs/Architecture.md
- docs/DataModel.md
- tasks/010-WeeklyTemplateSnapshotOnApply.md
- tasks/024-PeriodizedBlockModels.md
- tasks/025-PeriodizedBlockUI.md

## Current State (from audit)

- Weekly template apply with merge/overwrite exists — reuse patterns.
- No multi-week conflict detection.

## Scope

- User selects periodized block and starting week
- Calculate full date range (2–12 weeks)
- Detect existing workouts across **entire range** before applying
- Conflict prompt: Merge, Overwrite, Cancel
- Apply creates independent workouts with new IDs (via weekly snapshot logic)
- Display week names (Build, Peak, etc.) in planner for applied block weeks
- Set `linkedPeriodizedBlockId` on applied workouts

## Out of Scope

- Adaptive training logic.
- AI suggestions.

## Implementation Notes

Reuse weekly template snapshot-on-apply from Task 010 for each week in block.

Conflict detection runs before any writes.

## Acceptance Criteria

- The app builds.
- User can apply 2–12 week block from chosen start week.
- Conflicts detected across full range before apply.
- Merge, overwrite, cancel all work correctly.
- Week names visible in planner.
- Applied workouts independent from block template.

## Manual QA Checklist

- [ ] Apply 3-week block to empty calendar range.
- [ ] Apply to range with existing workouts: conflict prompt.
- [ ] Merge: existing + new workouts coexist.
- [ ] Overwrite: existing soft-deleted, block applied.
- [ ] Cancel: no changes.
- [ ] Week names display in planner headers.
