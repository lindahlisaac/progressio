# 030 - Reflection Gaps from 029 Review

## Objective

Close functional gaps found in the Tasks 028/029 code review so activity reflections fire on every complete path, discomfort reports do not duplicate on overwrite, and core reflection logic has tests.

## Required Context

Read:

- `docs/CursorInstructions.md`
- `docs/DataModel.md` (Reflections & Physical Discomfort)
- `tasks/ImplementationNotes.md` (reflections section)
- `tasks/028-SUBJECTIVE-DATA-COLLECTION-ANALYSIS`
- `tasks/029-subj-data-impl`
- Existing code:
  - `ViewModels/WeekPlannerViewModel+Reflections.swift`
  - `Views/WeekPlanner/WeekPlannerView.swift` (`requestActivityReflection`)
  - `Views/WeekPlanner/ActivityReflectionSheet.swift`
  - `ViewModels/WeekPlannerViewModel.swift` (`attachActualRun`, HealthKit match accept)

## Current State

Task 029 shipped standalone reflection / physical-issue entities, sheets, week-close validation, export/History, and CloudKit stores.

Review gaps:

1. Completing a workout via HealthKit attach or match-accept sets status `.completed` but does **not** open the activity reflection sheet.
2. Overwriting an activity reflection that includes discomfort always **appends** a new `ActivityIssueReport` instead of replacing prior reports for that reflection/workout.
3. No unit tests for reflection helpers (weekKey, unresolved filter, one-reflection-per-workout, resolve via weekly review).
4. Soft-deleting a workout leaves orphan `ActivityReflection` / issue reports (low priority).
5. Weekly reflection issue list shows **all** active `PhysicalIssue`s globally (acceptable for v1; optional tighten).

## Scope

### Must fix

**1. Open activity reflection after every HealthKit-driven complete**

Whenever a planned workout transitions to `.completed` via:

- `attachActualRun` (manual attach to planned)
- HealthKit match accept (same outcome path)

…the planner UI must call the same `requestActivityReflection(for:)` flow used by swipe / detail complete (including overwrite-vs-keep if a reflection already exists).

Notes:

- Prefer a single call site or shared helper so new complete paths do not forget the sheet.
- Do not open the sheet if status did not newly become `.completed` (e.g. re-attach that does not change status).
- Ad-hoc imported workouts created without completing a planned item: open reflection only if that new workout is marked completed and product intent is to reflect on it; otherwise focus on the planned-workout accept/attach paths above.

**2. No duplicate `ActivityIssueReport` on reflection overwrite**

When the user overwrites an existing `ActivityReflection` and (re)saves discomfort:

- Soft-delete or replace prior active `ActivityIssueReport`s tied to that `workoutID` / previous reflection before creating the new report(s).
- Keep history recoverable via soft-delete metadata (do not hard-delete).
- If overwrite clears discomfort (user turns it off), soft-delete prior reports for that workout/reflection rather than leaving stale links.

**3. Unit tests for core reflection logic**

Add focused tests (no UI / simulator required) covering at least:

- `WeekKey` / Monday `yyyy-MM-dd` formatting
- Unresolved workouts for week close (`.planned` / `.imported` unresolved; `.completed` / `.partiallyCompleted` / `.skipped` resolved; soft-deleted excluded)
- One active `ActivityReflection` per `workoutID` (upsert / overwrite behavior at model/store helper level)
- Weekly issue review that sets `PhysicalIssue` to resolved stamps `resolvedAt` and does not hard-delete

Place tests next to existing test targets / patterns in the repo.

### Should fix (same PR if small)

**4. Soft-delete reflections when a workout is soft-deleted**

When a workout is soft-deleted (or hard-removed if that path still exists), soft-delete its linked `ActivityReflection` and related active `ActivityIssueReport`s so History/export do not show orphans.

### Optional / defer if large

**5. Weekly issue relevance filter**

Optionally limit the weekly reflection issue list to issues that either:

- have an `ActivityIssueReport` in the current `weekKey`, or
- are still `.active`

Document the chosen rule in `ImplementationNotes.md` if changed. Current “all active” behavior is acceptable if left as-is; note the decision.

## Out of Scope

- Redesigning reflection scales / enums
- Changing week-complete storage (`isWeekComplete` stays on `WeekPlan`)
- Making weekly reflection mandatory
- New CloudKit record types beyond existing 029 types
- Broader History UI redesign
- Embedding reflections into Workout / WeekPlan blobs

## Implementation Notes

- Reuse `requestActivityReflection` / overwrite alert already in `WeekPlannerView`; wire HK complete paths into that rather than inventing a second sheet stack.
- Prefer ViewModel helpers that return the completed `workoutID` (or a “didNewlyComplete” flag) so the View can present the sheet without guessing.
- For issue-report replacement, centralize in `saveActivityIssueReport` / overwrite path in `WeekPlannerViewModel+Reflections.swift` so the sheet stays thin.
- Update `ImplementationNotes.md` briefly with: HK complete → reflection; overwrite replaces reports; any orphan-cleanup rule.
- Keep changes scoped to reflection/complete plumbing — do not drive-by refactor planner presentation files.

## Acceptance Criteria

- [x] App builds.
- [x] Accepting a HealthKit match onto a planned workout that becomes `.completed` opens the activity reflection sheet (overwrite prompt if one exists).
- [x] Attaching an unattached run to a planned workout that becomes `.completed` opens the activity reflection sheet.
- [x] Overwriting an activity reflection with discomfort does not leave multiple active reports for the same workout/issue; prior reports are soft-deleted or replaced.
- [x] Clearing discomfort on overwrite soft-deletes prior reports for that workout.
- [x] Unit tests cover weekKey, unresolved filter, one-reflection-per-workout, and resolve-via-weekly-review.
- [x] Soft-deleting a workout soft-deletes linked activity reflection + related reports (if item 4 implemented).
- [x] `ImplementationNotes.md` updated for the behaviors above.

## Manual QA Checklist

- [ ] Complete via swipe → reflection sheet.
- [ ] Complete via Run/Ride/Strength detail → reflection sheet.
- [ ] Attach HK run to planned workout → reflection sheet.
- [ ] Accept HK match to planned workout → reflection sheet.
- [ ] Re-complete with existing reflection → overwrite vs keep; after overwrite with discomfort, only one active report per issue for that workout.
- [ ] Overwrite with discomfort off → prior reports soft-deleted / inactive.
- [ ] Complete Week still validates unresolved; Skip still marks week complete without weekly reflection.
- [ ] Export / History still show reflections.
- [ ] Force sync still round-trips reflections/issues.

## Suggested Coding Agent Prompt

> Read `docs/CursorInstructions.md`, `tasks/ImplementationNotes.md`, and `tasks/030-ReflectionGapsFrom029Review.md`. Implement only this task. Do not move on to later tasks. Fix HealthKit complete → reflection, duplicate ActivityIssueReport on overwrite, and add the listed unit tests. Soft-delete linked reflections when a workout is soft-deleted if the change stays small.
