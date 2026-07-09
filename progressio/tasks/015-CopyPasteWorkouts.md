# 015 - Copy and Paste Workouts

## Objective

Implement long-press copy and paste for workouts in the weekly planner.

## Required Context

Read:

- docs/PlannerUX.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Copy/paste **not implemented**.
- Skip workflow already exists (Task 012 verifies).

## Scope

Implement workflow:

1. Long press workout → Copy
2. Select destination day → Paste
3. Prompt: paste planned values only **or** planned + completed values
4. Pasted workout receives **new UUID**
5. No live link to source workout

## Out of Scope

- Skip workflow (already implemented).
- Drag between days (Task 014).
- Copy across weeks (optional — same week minimum required).

## Implementation Notes

Store copied workout in view model clipboard state (not global pasteboard unless useful).

Copy deep-copies planned/completed value structs.

Reset `linkedHealthKitUUID` on paste unless user chose to include completed values and UUID is part of completed import (document behavior).

## Acceptance Criteria

- The app builds.
- Copy/paste creates independent workout with new ID.
- Planned-only paste: no completed values on copy.
- Full paste: both planned and completed values copied.
- Source workout unchanged after paste.
- Weekly totals update on destination day.

## Manual QA Checklist

- [ ] Copy planned run, paste to another day: new workout, planned values only.
- [ ] Copy completed run with "include completed": both value sets present.
- [ ] Edit pasted workout: original unchanged.
- [ ] Pasted workout has different ID from source.
