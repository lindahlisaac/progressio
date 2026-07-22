# 031 - Single Strength Path on WeekPlan

## Objective

Eliminate the leftover dual strength-data path so week plans own strength logging exclusively via `Workout.plannedValues` / `completedValues` snapshots. Remove production reads of `strengthlog-*.json` and quarantine (or delete) dead conversion helpers that keep `StrengthLogState` alive in the planner.

## Required Context

Read:

- `docs/CursorInstructions.md`
- `docs/DataModel.md` (Workout planned/completed strength snapshots)
- `docs/DataModel.puml` (Legacy / local-only package)
- `tasks/ImplementationNotes.md` (Task 021 notes + strength mid-session)
- `tasks/021-StrengthLogCloudSync.md` (original intent: no production file writes)
- Existing code:
  - `Views/WeekPlanner/StrengthLogView.swift`
  - `ViewModels/WeekPlannerViewModel.swift` (`updateCompletedStrengthSnapshot`, `exportCurrentWeek`)
  - `Services/Migration/StrengthLogPersistence.swift`
  - `Services/Migration/StrengthLogEmbedMigration.swift` (v7 — already embeds + deletes files)
  - `Models/Models.swift` (`StrengthLogState`, `ExerciseLog`, `PlannedSession`)
  - `Models/TemplateSnapshot.swift`
  - `Models/LegacySessionMapper.swift`

## Current State

Task 021 largely finished the migration:

- Mid-session / complete already **writes** `completedValues.completedStrengthRoutineSnapshot` through `onCompletedSnapshotPersist` → `WeekPlannerViewModel.updateCompletedStrengthSnapshot`.
- Migration v7 (`StrengthLogEmbedMigration`) embeds legacy files into week plans and deletes `strengthlog-*.json`.
- Import no longer rewrites strength log files.

**Still dual-path (cleanup debt):**

1. `StrengthLogView` **falls back to loading** `strengthlog-{workoutID}.json` when both snapshots are empty.
2. `exportCurrentWeek` **falls back to loading** the same files when the snapshot is missing.
3. `WeekPlannerViewModel.strengthLogState(from:)` remains as a reverse converter (legacy shape) even though import no longer needs it.
4. `StrengthLogPersistence` / `StrengthLogState` still look like live storage APIs rather than migration-only.
5. Docs / PlantUML still describe mid-session file writes as current behavior in places.

`PlannedSession` decode on `DayPlan` / `WeekPlan` (legacy `sessions` key) is a **separate** legacy-compat path. Keep decode for old JSON imports; do **not** expand this task into deleting `PlannedSession` unless it is trivial after strength cleanup. Prefer quarantining comments + “decode-only” notes over a risky delete.

## Scope

### Must do

**1. Strength UI reads workout snapshots only**

In `StrengthLogView`:

- Seed exercises from `completedStrengthRoutineSnapshot`, else `plannedStrengthRoutineSnapshot`, else empty.
- **Remove** the `StrengthLogPersistence.load(...)` fallback branch in `init`.
- Keep persisting only via `onCompletedSnapshotPersist` (week plan). No file I/O.

**2. Week export uses embedded snapshots only**

In `exportCurrentWeek`:

- Include strength data only from `completedValues.completedStrengthRoutineSnapshot` (and planned if you already export that via the week JSON).
- **Remove** the legacy file fallback that loads `strengthlog-*.json`.
- Count / log based on embedded snapshots only.

**3. Delete dead planner conversion to `StrengthLogState`**

- Remove unused `strengthLogState(from:)` (and any other dead StrengthLogState helpers) from `WeekPlannerViewModel` if nothing calls them after (1)–(2).
- Keep `TemplateSnapshot` ↔ `ExerciseLog` mapping — `ExerciseLog` / `SetLog` remain valid **UI editing** types for `StrengthLogView`.

**4. Quarantine file persistence as migration-only**

- Mark `StrengthLogPersistence` as migration/legacy-only (file header comment + avoid new call sites).
- Production app code outside `Services/Migration/` must not call it.
- `StrengthLogEmbedMigration` / older migration steps may keep using it.
- Optionally move or rename for clarity (e.g. leave in Migration folder with a `Legacy` prefix) — only if low-churn; do not rearrange the whole migration tree.

**5. Docs**

Update briefly:

- `ImplementationNotes.md` — single strength path: snapshots on Workout inside WeekPlan; no production `strengthlog-*.json` reads/writes.
- `DataModel.md` / `DataModel.puml` — demote `StrengthLogState` / file logs to `<<legacy>>` / migration-only (not current mid-session store).

### Should do (same PR if small)

**6. One-shot orphan file sweep (optional, safe)**

If any devices might still have leftover `strengthlog-*.json` after v7:

- On launch after migrations, or inside an existing settings “data tools” cleanup if one fits, delete orphan `strengthlog-*.json` **only when** the matching workout already has a completed snapshot **or** no matching workout exists.
- Prefer not introducing a new migration version unless necessary; a best-effort Documents sweep is enough if v7 already ran for all users.

**7. Narrow `PlannedSession` documentation**

- Comment on `PlannedSession` / `DayPlan` legacy `sessions` decode: decode-only for old imports; encoder writes `workouts` only.
- Do not change encode/decode behavior in this task unless a bug is found.

## Out of Scope

- Splitting WeekPlan CloudKit blob / per-workout sync
- Rewriting strength UI to edit `StrengthRoutineSnapshot` directly (UI may keep `ExerciseLog`)
- Deleting `PlannedSession` / `LegacySessionMapper` entirely
- Changing template snapshot-on-apply behavior
- New CloudKit record types
- Typed (non-String) metric fields
- Reflection / Task 030 work

## Implementation Notes

- Source of truth after this task:
  - **Planned strength:** `Workout.plannedValues.plannedStrengthRoutineSnapshot`
  - **In-progress + completed strength:** `Workout.completedValues.completedStrengthRoutineSnapshot` (mid-session writes while status may still be `.planned` — already documented; History filters by status)
- `ExerciseLog` staying as a view model type is fine — the smell is **file dual storage**, not the UI adapter.
- Do not reintroduce file writes “for offline mid-session safety”; week plan persist is the durability path.
- Grep for `StrengthLogPersistence`, `strengthlog-`, and `StrengthLogState` after changes; production call sites should be migration/tests/legacy mapper only.
- `LegacySessionMapper` may still map `PlannedSession.strengthLog` ↔ snapshots for old session JSON — that is decode bridge, not a live dual path.

## Acceptance Criteria

- [x] App builds.
- [x] `StrengthLogView` never reads or writes `strengthlog-*.json`.
- [x] Mid-session edits still persist through `updateCompletedStrengthSnapshot` into the week plan and survive relaunch / force sync.
- [x] Completing a strength workout keeps planned snapshot intact and completed snapshot present.
- [x] Week export JSON includes embedded completed strength snapshots when present; no file fallback.
- [x] Week import still restores embedded snapshots without creating strength log files.
- [x] No production (non-Migration) call sites to `StrengthLogPersistence` remain (except possibly a documented one-shot orphan sweep).
- [x] `ImplementationNotes.md` + DataModel docs/puml updated to describe the single path.
- [x] Grep clean for accidental dual-path regressions in Views/ViewModels.

## Manual QA Checklist

- [ ] Apply strength template → open log → planned exercises appear from workout snapshot (no file).
- [ ] Edit sets mid-session, leave screen, reopen → edits restored from week plan.
- [ ] Force sync / relaunch → mid-session completed snapshot still present; status still planned until Complete.
- [ ] Mark complete → status completed; reopen locked with completed snapshot.
- [ ] Unlock → edit → complete again → snapshot updates on week plan.
- [ ] Export week → JSON contains `completedStrengthRoutineSnapshot`; no dependency on Documents `strengthlog-*.json`.
- [ ] Import that export → strength data present without creating new strength log files.
- [ ] Prior-session comparison / History strength detail still work from embedded snapshots.

## Suggested Coding Agent Prompt

> Read `docs/CursorInstructions.md`, `tasks/ImplementationNotes.md`, and `tasks/031-SingleStrengthPathOnWeekPlan.md`. Implement only this task. Do not move on to later tasks. Remove all production reads of `strengthlog-*.json` from StrengthLogView and week export; keep snapshots on the Workout inside WeekPlan as the only strength path; quarantine StrengthLogPersistence as migration-only; update docs. Leave PlannedSession decode for legacy imports unless cleanup is trivial.
