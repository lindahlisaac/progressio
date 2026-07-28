# Implementation Notes

Audit completed in **Task 001** (branch `feature/mega-overhaul`, commit `52dcbbd`).

This file is the living implementation map for Progressio. Later tasks should read it before modifying code.

---

## Current Architecture Summary

Progressio is a **SwiftUI iOS app** with **no active Core Data usage**. The app entry point (`progressioApp.swift`) loads `ContentView` directly and does not wire up `PersistenceController`.

Persistence is **JSON file–backed** under `Documents/progressio/`, wrapped by **store protocols** in `Storage.swift`, with **CloudKit private database sync** via `CloudKitStores.swift` and **last-writer-wins merge** in `SyncingStores.swift`.

The domain model lives in a single file: `Models/Models.swift`. Business logic is concentrated in two view models:

- `WeekPlannerViewModel` — week navigation, sessions, templates apply, HealthKit import orchestration, export/import
- `TemplateLibraryViewModel` — strength/run workout templates CRUD

**Navigation** (`ContentView.swift`): Plan → Templates → History → Settings.

**Strength logging** lives on the week-plan `Workout`: planned and completed `StrengthRoutineSnapshot`s. Standalone `strengthlog-*.json` is migration-only (Task 031).

---

## Persisted Models (Current)

All models are `Codable` structs in `Models/Models.swift`.

| Model | Purpose | Stable ID | Timestamps | Sync metadata |
|-------|---------|-----------|------------|---------------|
| `PlannedSession` | One workout on a calendar day (the de-facto "workout") | `id: UUID` | `updatedAt` optional | `etag` optional |
| `DayPlan` | One day in a week | `id: UUID` | `updatedAt` optional | `etag` optional |
| `WeekPlan` | Monday–Sunday plan | — (keyed by `startOfWeek`) | `updatedAt` optional | `etag` optional |
| `StrengthTemplate` | Reusable strength or run template | `id: UUID` | `updatedAt` optional | `etag` optional |
| `WeeklyTemplate` | Reusable week schedule | `id: UUID` | `updatedAt` optional | `etag` optional |
| `DayTemplate` | Day within weekly template | `id: UUID` | — | — |
| `UnattachedRun` | Imported HealthKit run awaiting attach | `id: UUID` | `updatedAt` optional | `etag` optional |
| `RunDetailData` | Planned or actual run/ride details | — | `updatedAt` optional | `etag` optional |
| `StrengthLogState` | **Legacy** file-backed strength log (migration decode only) | `sessionID: UUID` | `updatedAt` optional | `etag` optional |

**Not present** (required by target docs): `schemaVersion`, `createdAt`, `isDeleted`, `deletedAt`, unified `Workout` type, `plannedValues`/`completedValues` structs, `WorkoutSource`, `timePeriod` (AM/PM), separate endurance templates, periodized blocks, `ImportedHealthWorkoutReference`.

### Enums (current vs target)

| Current | Target (docs) |
|---------|---------------|
| `SessionKind`: Strength, Run, Cycle | `ActivityType`: Road Run, Trail Run, Walk, Bike, Strength |
| `PlanStatus`: Planned, Completed, Unplanned, Skipped | `WorkoutStatus`: + Imported, Partially Completed; no Unplanned |
| `TemplateCategory`: Strength, Run | Separate strength + endurance template types |
| `RunCategory`: Easy, Recovery, Tempo, Threshold, VO2, Race | Same + Long Run |

---

## Current Workout Model Structure

The app does **not** have a `Workout` type. `PlannedSession` is the workout primitive embedded in `DayPlan.sessions`.

```
PlannedSession
├── id, title, kind (SessionKind), status (PlanStatus)
├── note, templateName (String link by name only)
├── runDetail: RunDetailData?      ← planned run/ride data
├── actualRun: RunDetailData?      ← completed run/ride data (separate struct)
├── strengthLog: StrengthLogState? ← only populated during week export/import
└── updatedAt, etag
```

**Planned vs completed (runs/rides):** Partially correct. `runDetail` holds planned values; `actualRun` holds completed values. `RunDetailView` and `RideDetailView` edit them separately.

**Planned vs completed (strength):** *(superseded by Tasks 008/021/031)* Strength plan + log live on `Workout` snapshots inside `WeekPlan`. `strengthlog-*.json` is migration-only.

**Gaps vs docs:**

- No `source` field on sessions (Manual / Template / Apple Health)
- `PlanStatus.unplanned` used for ad-hoc/imported; docs use `Imported` status
- No `linkedHealthKitUUID` on session — UUID lives inside `RunDetailData.hkWorkoutUUID`
- No `timePeriod` (AM/PM) for matching
- `Cycle` maps to docs' `Bike`; no Walk, Trail Run, Road Run distinction
- Strength templates linked by **name string**, not stable template ID

---

## Template-Related Code

| Area | File(s) | Notes |
|------|---------|-------|
| Strength/run templates CRUD | `TemplateLibraryViewModel.swift`, `Views/Templates/TemplateLibraryScreen.swift` | Single `StrengthTemplate` type serves both strength and run categories |
| Weekly templates CRUD | `TemplateLibraryScreen.swift`, `WeeklyTemplateListView.swift`, `WeeklyTemplateDetailView.swift` | Weekly templates store `[PlannedSession]` per day |
| Apply workout template to day | `WeekPlannerViewModel.addTemplateSession`, `WeekPlannerView` template picker | Creates new `PlannedSession` with new UUID; copies `runDetail` for runs |
| Apply weekly template | `WeekPlannerViewModel.applyWeeklyTemplate` | Merge or override; copies sessions **with original IDs** from template |
| Save week as template | `WeekPlannerViewModel.saveWeeklyTemplate` | Copies current week's `PlannedSession` array into `DayTemplate` |
| Strength log seeding | `StrengthLogView.init` | Looks up template **by name** at view open; seeds exercises if no saved log |

**Template independence risks:**

1. **Weekly template apply** reuses session UUIDs from the template — can cause ID collisions when merging with existing week sessions.
2. **Strength sessions** partially depend on live template lookup by name in `StrengthLogView` — renaming a template breaks the link; editing template exercises affects newly opened sessions that have no saved log yet.
3. **Weekly templates** embed full `PlannedSession` structs rather than independent snapshots with new IDs (docs require copy-on-apply).

---

## Weekly Planner Implementation

| Component | File |
|-----------|------|
| Main planner UI | `Views/WeekPlanner/WeekPlannerView.swift` |
| View model | `ViewModels/WeekPlannerViewModel.swift` |
| Run detail / logging | `Views/WeekPlanner/RunDetailView.swift` |
| Ride detail / logging | `Views/WeekPlanner/RideDetailView.swift` |
| Strength logging | `Views/WeekPlanner/StrengthLogView.swift` |
| Unattached runs UI | `Views/WeekPlanner/UnattachedRunsView.swift` |
| Weekly totals (partial) | Inline computed properties in `WeekPlannerView` + `Views/Reports/WeeklyReportView.swift` |

**Implemented planner features:**

- Monday-start week view with prev/next navigation
- Multiple sessions per day
- Add workout menu (run, ride, strength, template, detected run)
- Status toggle (planned ↔ completed), skip with optional note
- Swipe delete
- Weekly template apply with merge/override alert
- Basic weekly report (run miles, ride miles, strength session counts)
- Export/import current week as JSON (includes embedded strength logs)

**Not implemented (per PlannerUX.md):**

- Drag and drop between days
- Copy/paste workouts
- AM/PM time periods
- Top-of-week totals row (totals live in a separate report link)
- Imported/ad-hoc visual indicators beyond status badge
- Create template from week (save exists in view model; UI may be in template screen)

---

## Apple Health Import Implementation

| Component | File |
|-----------|------|
| HealthKit queries | `Services/HealthKitManager.swift` |
| Import service | `Services/HealthKitImportService.swift` |
| Import orchestration | `WeekPlannerViewModel+HealthKitImport.swift` (`processHealthKitCandidates`) |
| Manual import trigger | `Views/Settings/SettingsView.swift` ("Import last 7 days") |
| Attach to planned / new | `WeekPlannerViewModel.attachActualRun`, `UnattachedRunsView` |
| UUID reference store | `ImportedHealthWorkoutReference` + migration v6 |

**Import flow (current):**

1. Settings → `fetchCandidatesForcingRefresh` → `HealthKitImportCandidate` with `hkWorkoutUUID`.
2. `processHealthKitCandidates` skips known UUIDs (references, unattached, local week files) and appends new runs to **Unattached only**.
3. User opens Plan → Unattached and attaches to a planned workout or creates a new day entry.
4. No Plan `onAppear` observer / auto-apply (removed after duplicate calendar spam).

**Recovery:** Settings → Clean up duplicate imports strips `appleHealth` / `.imported` calendar rows across weeks and restores unique UUIDs to Unattached.
---

## iCloud / CloudKit Sync Implementation

| Layer | File |
|-------|------|
| Store protocols | `Services/Storage.swift` |
| File-backed stores | `Services/Storage.swift` (`File*Store`) |
| CloudKit stores | `Services/CloudKitStores.swift` |
| Syncing wrappers | `Services/SyncingStores.swift` |

**CloudKit record types** (private database, container `iCloud.com.eyelind.progressio`):

| Record type | Key | Payload |
|-------------|-----|---------|
| `StrengthTemplate` | `{type}-{uuid}` | JSON `[StrengthTemplate]` per record (one record per template) |
| `WeeklyTemplate` | `{type}-{uuid}` | JSON per weekly template |
| `UnattachedRun` | `{type}-{uuid}` | JSON per unattached run |
| `WeekPlan` | `{type}-{ISO date}` | JSON entire week |

**Conflict resolution:** Last-writer-wins on `updatedAt` at the record level. Week plans merge as a single blob — no per-session merge.

**Not synced:**

- Legacy `strengthlog-*.json` (migration-only leftovers; strength data syncs inside `WeekPlan`)
- Core Data (`Persistence.swift` / `progressio.xcdatamodeld`) — unused boilerplate (removed in Task 027)

**Sync gaps vs docs:**

- No soft deletes / tombstones — hard delete removes from array and overwrites CloudKit record
- No `schemaVersion` on payloads
- No `createdAt` — only `updatedAt`
- CloudKit saves use `savePolicy = .allKeys` with no delete propagation for removed records (orphan CK records possible)
- Blocking semaphores on main thread for CloudKit reads

---

## Migration Strategy (Current)

**None implemented.**

- No `schemaVersion` field on any model
- No migration runner or version gate on app launch
- `Codable` structs rely on optional fields and custom `init(from:)` only in `StrengthLogState`
- Week export/import and file stores assume current struct shape
- Core Data model contains unused `Item` entity — not part of active data path

Any data model refactor (Task 002+) must introduce explicit migration from:

- `templates.json`
- `weeklyTemplates.json`
- `unattachedRuns.json`
- `weekplan-*.json`
- `strengthlog-*.json`

---

## Gap Summary vs Target Docs

| Target | Current state |
|--------|---------------|
| Unified `Workout` with planned/completed value structs | `PlannedSession` + split run/strength storage |
| Activity types: Road/Trail Run, Walk, Bike, Strength | `SessionKind`: Strength, Run, Cycle |
| Status: Imported, Partially Completed | `PlanStatus.unplanned` instead |
| `WorkoutSource` | Not tracked |
| `timePeriod` AM/PM | Not implemented |
| Endurance templates (separate from strength) | Run templates reuse `StrengthTemplate` with `category: .run` |
| Periodized blocks | Not implemented |
| History tab | Not implemented |
| HealthKit UUID dedup + user matching flow | Partial dedup; no user prompt; `hasAttachedRun` unused |
| Schema versioning + soft deletes | Not implemented |
| Strength log cloud sync | Local files only |

---

## Risk Areas

1. **Data model refactor without migration** — users have JSON + CloudKit data in legacy shape; breaking `Codable` silently loses data.
2. **CloudKit orphan records** — saves never delete removed templates/runs/weeks from CloudKit; merges only add/update.
3. **Strength logs not synced** — multi-device users lose strength completion data.
4. **Weekly template ID reuse** — applying templates can duplicate UUIDs within a week.
5. **Template live-link by name** — violates docs' independence rule for strength sessions.
6. **HealthKit duplicate imports** — two import entry points; dedupe is signature-based but not UUID-enforced at import boundary; observer re-fires.
7. **Week plan blob sync** — entire week is one record; concurrent edits on two devices lose granular changes.
8. **Main-thread CloudKit blocking** — `DispatchSemaphore.wait()` in cloud stores may cause UI jank.
9. **Concentrated view model** — `WeekPlannerViewModel` (~670 lines) mixes planner, sync, import, export, template apply; high regression risk during refactor.

---

## Suggested Refactor Sequence

Aligned with `tasks/README.md` ordering:

1. **002 — Workout Types and Metadata** — Add target `Workout`, planned/completed value types, enums, and legacy mappers; no behavior change yet.
2. **003 — Migration Infrastructure** — Migration runner, version gate, stub steps for 004–005.
3. **004–005 — Data Migration** — Migrate week plans, templates, and strength logs from legacy JSON.
4. **006 — Sync Metadata and Soft Deletes** — Timestamps, schema version, tombstones in JSON + CloudKit.
5. **007 — Wire View Models** — Switch planner VM/views from `PlannedSession` to `Workout`.
6. **008–010 — Template Independence** — Snapshot-on-apply for workout and weekly templates; endurance template split.
7. **011–015 — Planner UX** — Activity types, status indicators, totals, drag, copy/paste.
8. **016–017 — Templates UI** — Template library refactor and weekly template polish.
9. **018–020 — Apple Health** — Consolidate import pipeline, UUID dedup, planned matching with user prompt.
10. **021 — Strength Log Cloud Sync** — Embed completion data in workout sync payload.
11. **022–023 — History and Settings** — History tab, settings/data tools.
12. **024–026 — Periodized Blocks** — Models, UI, apply to calendar.
13. **027 — Final Polish** — Release checklist and QA.

---

## Task Completion Notes

For each completed task, record **what shipped** and a **Major decisions** subsection (why those code choices were made). Agents must update both when finishing a task.

### Task 002 — Workout Types and Metadata

- Added target types under `Models/`: `Workout`, `WorkoutEnums`, `WorkoutValues`, `WorkoutSchema`, `LegacySessionMapper`.
- Legacy `PlannedSession` / stores / UI unchanged until Task 007.
- `LegacySessionMapperTests` in `progressioTests/`.

**Major decisions**
- Introduced new types alongside legacy instead of in-place rewrite, so planner/UI could keep shipping while migrations caught up.
- Kept `LegacySessionMapper` as the explicit bridge (lossy round-trips documented) rather than pretending one model covered both eras.

### Task 003 — Migration Infrastructure

- `Services/Migration/`: `MigrationRunner`, `MigrationStep`, `AppDataMigration`, `LegacyDataDecoder`, `MigrationBackup`.
- Runs on launch via `progressioApp.init()`; persists `Documents/progressio/dataVersion.json`.
- `latestVersion` advances only as migration steps ship (avoid no-op stubs bumping version).

**Major decisions**
- Version gate is app-data-wide (`dataVersion.json`), separate from per-record `schemaVersion`.
- Steps are strictly sequential (`currentVersion + 1` only) so partial upgrades are recoverable and auditable.

### Task 004 — Migrate Week Plans and Workouts

- On-disk week format: `MigratedWeekPlan` / `MigratedDayPlan` with `[Workout]` and `formatVersion`.
- `WeekPlanMigration`, `WeekPlanMapper`, `WeekPlanPersistence` — backup, migrate, dual-read.
- `FileWeekPlanStore` / `CloudWeekPlanStore` dual-read legacy or migrated JSON; save writes migrated format.
- `SyncingWeekPlanStore` merge comment documents LWW + dual-read policy.
- App data version **v2** after week-plan migration.

**Major decisions**
- Dual-read + write-forward: old week JSON still loads; every save writes migrated shape.
- Backup before rewrite so a bad migration is recoverable without CloudKit archaeology.

### Task 005 — Migrate Templates and Strength Logs

- **Model metadata** added to `StrengthTemplate`, `WeeklyTemplate`, `DayTemplate`, `StrengthLogState`:
  `schemaVersion`, `createdAt`, `updatedAt`, `isDeleted`, `deletedAt` (templates); custom `init(from:)` defaults for legacy JSON.
- **Migration helpers**: `MetadataStamping`, `TemplatePersistence`, `StrengthLogPersistence`, `TemplateAndStrengthLogMigration`.
- **On launch (v3 step)**: backs up and stamps `templates.json`, `weeklyTemplates.json`, `strengthlog-*.json`; optionally embeds strength log snapshots into matching `Workout.completedValues` in migrated week plans (by session UUID).
- **Stores / UI**: `FileTemplateStore` / `FileWeeklyTemplateStore` use `TemplatePersistence`; `StrengthLogView` uses `StrengthLogPersistence`.
- **Still legacy**: weekly template days embed `[PlannedSession]` (snapshot fix is Task 010); strength logs remain local files (CloudKit sync is Task 021).

**Major decisions**
- Stamp metadata in place rather than inventing new template file formats yet (format splits deferred to 009/010).
- Embed completed strength snapshots into week workouts when UUID matches; leave file-backed logs as source of truth until Task 021.

### Task 006 — Sync Metadata and Soft Deletes

- **`SyncMetadata`** — `softDelete`, `stampNewRecord`, `stampSave`, `stampLegacy` for templates, weekly templates, unattached runs, week plans.
- **`SyncRecordMerge`** — per-ID merge for template collections; tombstone-aware `pick` for week-plan envelope conflicts.
- **`SyncingStores`** — all four syncing wrappers merge with `SyncRecordMerge`; tombstoned records stay in saved payloads for propagation.
- **View models** — `deleteTemplate`, `deleteWeeklyTemplate`, `removeUnattachedRun`, `clearUnattachedRuns` soft-delete; `activeTemplates` / `activeWeeklyTemplates` / `activeUnattachedRuns` filter UI.
- **Models** — `WeekPlan`, `MigratedWeekPlan`, `UnattachedRun` gained sync metadata; `WeekPlanMapper` / `WeekPlanPersistence` pass through `isDeleted` / `schemaVersion`.
- **Docs** — `SyncAndMigration.md` updated with tombstone merge policy.
- **Follow-up fix** — `SyncRecordMerge.pick` corrected so newer active records win over older tombstones; resurrection still blocked when active is newer than an existing tombstone (`SyncRecordMergeTests`).
- **Known gaps (acceptable for 006)**: planner `removeSession` still hard-deletes sessions (workout-level soft delete is Task 007+); CloudKit orphan record cleanup deferred; strength logs still local-only (Task 021).

**Major decisions**
- Soft deletes keep tombstones in payloads so CloudKit merge can propagate deletes across devices.
- Merge policy prefers newer active over older tombstone, but blocks resurrection when tombstone is newer — encoded in tests after an early bug.

### Task 007 — Wire View Models to Workout Model

- **`DayPlan`** — `sessions: [PlannedSession]` replaced with `workouts: [Workout]`; decoder accepts legacy `sessions` key for import/export compatibility.
- **`WeekPlanMapper`** — maps `WeekPlan` ↔ `MigratedWeekPlan` without `PlannedSession` round-trip at store boundary.
- **`Workout+Planner.swift`** — factories, display helpers, `WorkoutEditing` for endurance attach/save.
- **`WeekPlannerViewModel`** — CRUD, template apply, HealthKit attach, export/import all use `Workout`.
- **Planner views** — `WeekPlannerView`, `RunDetailView`, `RideDetailView`, `StrengthLogView`, `UnattachedRunsView` take `Workout`; `WorkoutRow` replaces `SessionRow`.
- **Still legacy at template boundary**: `DayTemplate.sessions` remains `[PlannedSession]` until Task 010; weekly template apply converts via `LegacySessionMapper`.

**Major decisions**
- Switched planner domain to `Workout` at the `DayPlan` boundary first; left weekly templates on `PlannedSession` to avoid coupling Task 007 to Task 010.
- Kept legacy `sessions` decode path so export/import and older week JSON still work without a second migration.

### Task 008 — Template Snapshot on Apply

- **`TemplateSnapshot.swift`** — copies `StrengthTemplate` exercises into `StrengthRoutineSnapshot`; maps snapshots ↔ `ExerciseLog` for UI seeding and completion.
- **`Workout.from(template:)`** — sets `linkedWorkoutTemplateId` for all template types; strength templates copy `plannedValues.plannedStrengthRoutineSnapshot` on apply.
- **`StrengthLogView`** — seeds from workout snapshot (planned or completed), not live template lookup; syncs `completedStrengthRoutineSnapshot` to week plan on mark-complete.
- **`WeekPlannerView`** — removed `templatesViewModel` template-by-name lookup for strength detail navigation.
- **Still legacy**: weekly template apply (Task 010); strength logs remain file-backed with snapshot sync on complete (full CloudKit sync is Task 021).

**Major decisions**
- Canonical link is `linkedWorkoutTemplateId`; `templateName` kept as display-only metadata.
- Snapshot lives on the workout (`plannedValues` / `completedValues`); strength UI still persists mid-session edits to local files so Task 021 can migrate completion sync later without blocking independence.

### Task 009 — Endurance Template Model Split

- **`EnduranceTemplate.swift`** — dedicated model with activity type, run type, planned distance/duration/elevation, description, RPE, route; sync metadata.
- **Migration v4** — `EnduranceTemplateMigration` moves legacy non-strength (`TemplateCategory.endurance`, including old `"Run"`) into `enduranceTemplates.json`, preserving IDs; strength-only records remain in `templates.json`.
- **Stores** — `EnduranceTemplateStore`, file/CloudKit/syncing wrappers parallel to strength templates.
- **`Workout.from(template: EnduranceTemplate)`** — copies planned values into independent workout snapshot on apply.
- **`TemplateLibraryViewModel`** — manages strength and endurance templates separately; `RunCategory.longRun` added with full `RunType` bridge.
- **UI** — Templates library, planner template picker, and weekly template picker use `EnduranceTemplate` for endurance; strength templates unchanged.
- **Follow-up** — `TemplateCategory` renamed conceptually to Strength / Endurance (`case endurance = "Endurance"`); legacy JSON `"Run"` still decodes as `.endurance`.

**Major decisions**
- Separate file + CloudKit record type (`enduranceTemplates.json` / `EnduranceTemplate`) instead of a discriminated union in one array — clearer store boundaries and avoids rewriting all strength sync paths.
- Preserve legacy template UUIDs on migrate so existing `linkedWorkoutTemplateId` references stay valid.
- Activity type (road/trail/walk/bike) is a field on `EnduranceTemplate`, not a top-level template category; category is only Strength vs Endurance.

### Task 010 — Weekly Template Snapshot on Apply

- **`WeeklyTemplateWorkoutEntry`** — planned-only snapshot (activity, run type, planned values, optional linked template ID); apply always creates a new workout UUID.
- **`DayTemplate.workoutEntries`** — replaces embedded `sessions: [PlannedSession]`; decoder migrates legacy `sessions` on read; encoder writes `workoutEntries` only.
- **`applyWeeklyTemplate`** — merge appends new IDs; overwrite soft-deletes existing active workouts then applies copies; sets `linkedWeeklyTemplateId`.
- **`saveWeeklyTemplate`** — stores snapshots from active workouts, not live references.
- **Migration v5** — rewrites `weeklyTemplates.json` from legacy sessions to workout entry snapshots.
- **UI** — weekly template create/edit/detail and planner list use `workoutEntries`; planner day list filters via `DayPlan.activeWorkouts`.
- **Follow-up UX** — planner toolbar menu for Apply Weekly Template vs Save Week as Template.

**Major decisions**
- Store planned-only entries in the template (no completed values) so templates stay blueprints.
- Apply always allocates new workout IDs; overwrite soft-deletes prior active workouts instead of hard-removing, to keep sync tombstones consistent with Task 006.
- `DayPlan.activeWorkouts` filters deleted workouts in UI/totals without dropping tombstones from persistence.

### Task 011 — Planner Activity Types and Add Flow

- **Add menu** — modality-first: Road Run, Trail Run, Walk, Bike, Strength; each offers Blank AM/PM and From template AM/PM when templates exist for that modality.
- **`Workout.manual` / `from(template:timePeriod:)`** — create with correct `ActivityType`, `source`, and `timePeriod` (default AM).
- **Template picker** — filtered by selected modality (strength vs matching endurance activity type).
- **AM/PM** — set on add; editable in `RunDetailView`, `RideDetailView` (Bike), and `StrengthLogView`; shown on `WorkoutRow`.
- User-facing "Ride" → "Bike" in planner add/detail strings.

**Major decisions**
- Nested menus (modality → blank/template → AM/PM) instead of a multi-step sheet — fewer screens, matches “minimal taps” in PlannerUX.
- Template picker is modality-scoped (exact `activityType` for endurance) so a Trail Run template is not offered under Road Run.
- Default `timePeriod` to AM when unset so Apple Health matching (Task 020) has a stable baseline.
- Kept `RideDetailView` type name; only user-facing strings say Bike, to avoid a large rename churn for Task 011.

### Task 012 — Planner Status Indicators

- Distinct `WorkoutStatus.tint` values: Planned blue, Done green, Partial teal, Imported orange, Skipped gray.
- Compact `badgeLabel` on rows (`Partial` / `Done` instead of full enum strings).
- Skipped: title struck through + skip reason shown; strength notes no longer duplicate skip reason via `displayNote`.

**Major decisions**
- Kept single capsule badge pattern; differentiated Partial with a teal tint rather than a second badge to stay minimal.
- Skip reason is row-level text (italic), not a chip — avoids competing with status/time-period capsules.
- **Follow-up:** skip sheet prefills `skipReason` only when already skipped (not `notes` / “From template”).

### Task 013 — Weekly Totals

- **`WeekTotals.swift`** — per-modality completed/planned helper; rows only for activity types present in the week.
- Inline “Weekly totals” section at top of planner; skipped → planned only; completed + partial → completed.
- Bike uses miles when any distance exists, otherwise duration hours.
- `WeeklyReportView` aligned to same totals model (optional detail retained conceptually).

**Major decisions**
- Extracted totals out of the view into a pure helper so drag/paste refresh without duplicating math.
- Modality-split (road vs trail vs walk) instead of lumping all runs — matches PlannerUX.
- **Follow-up:** `WeekTotalsTests` covers skip/planned, soft-delete exclusion, bike duration fallback, modality filtering.

### Task 014 — Drag Workouts Between Days

- `.draggable` workout UUID + section `.dropDestination`.
- `moveWorkout` keeps ID, updates `plannedDate` / day membership.
- Confirmation when completed values, partial/completed status, strength completion snapshot, or HealthKit UUID present.

**Major decisions**
- Transfer payload is UUID string (simple, List-friendly) rather than a custom `Transferable` workout payload.
- Confirm only for data-bearing workouts; planned blanks move immediately.
- **Follow-up:** `removeWorkout` soft-deletes (tombstone) instead of hard-removing from the day array.

- Context menu Copy; “Paste workout” button on days when clipboard is set.
- Prompt: planned-only vs planned+completed; always new UUID; clears weekly-template link; planned-only clears HK UUID and completed values.

**Major decisions**
- In-app VM clipboard (not UIPasteboard) so paste stays inside the planner and doesn’t collide with system paste.
- Planned-only paste forces `source = manual` and drops HK link so copies aren’t falsely treated as imports.

### Task 016 — Templates UI Refactor

- Verified Strength/Endurance sections, CRUD, soft delete, exercise reorder already in place from 009–011.
- Added empty-state copy for both sections; delete alerts clarify applied workouts are unaffected.

**Major decisions**
- Gap-fill only — no screen rewrite; acceptance criteria were largely already met.

### Task 017 — Weekly Templates Polish

- Blank add menus include all `plannerAddTypes` (Road/Trail/Walk/Bike/Strength).
- Strength entries in weekly template preview navigate to read-only routine snapshot detail.
- Save-from-week, apply conflict prompt, and soft delete already in place from Task 010.

**Major decisions**
- Shared `WeeklyTemplateWorkoutEntry.blank(activityType:)` helper so create and edit menus stay in sync with planner modalities.

### Task 018 — Consolidate HealthKit Import Pipeline

- `HealthKitImportService` is the single entry point for Settings import (shared 7-day lookback).
- `HealthKitManager` maps `HKWorkout` → `HealthKitImportCandidate`; views no longer call import mapping directly.
- Plan no longer starts a HealthKit observer or auto-fetches on appear (caused launch freezes + duplicate calendar writes).

**Major decisions**
- Consolidated lookback to 7 days in one constant.
- Fingerprint short-circuit remains for forced refetch noise; Settings uses `fetchCandidatesForcingRefresh`.
- **Rollback (post-020):** import is Settings-triggered only; no background observer on Plan.

### Task 019 — Apple Health UUID Dedup

- `ImportedHealthWorkoutReference` persisted locally + CloudKit; migration v6 seeds from existing linked/unattached UUIDs and soft-deletes duplicate unattached rows.
- Import skips when UUID exists in references, attached workouts (local week files), or unattached list.
- Known-UUID scan uses `FileWeekPlanStore` only (no CloudKit week fetches during import).

**Major decisions**
- Reference table is the durable idempotency key; signature hashing remains only for UUID-less fallback/unattached paths.
- Local-only week scan avoids SyncingWeekPlanStore freezes and stale merge re-adds.

### Task 020 — Apple Health Planned Matching

- **Rolled back to Unattached-first:** imports land in Plan → Unattached; user attaches manually (apply to planned or create new).
- Auto calendar apply and AM/PM match confirmation dialogs removed from Plan/Settings.
- Settings “Clean up duplicate imports” strips auto-imported calendar workouts across weeks and restores unique UUIDs to Unattached.

**Major decisions**
- Manual attach is the product path until auto-match feels reliable; avoids silent overwrite and duplicate day spam.
- Cleanup is destructive for `source == appleHealth` / `status == imported` calendar rows only; planned workouts stay.

### Task 021 — Strength Log Cloud Sync

- Strength logging writes `completedValues.completedStrengthRoutineSnapshot` on the workout (syncs with week plan).
- Migration v7 embeds legacy `strengthlog-*.json` into workouts and removes standalone files.
- `StrengthLogView` no longer writes strength log files in the production path.

**Major decisions**
- Option A (embed in workout) over a separate CloudKit strength-log store — week plan stays the sync unit.
- Mid-session edits persist the completed snapshot without forcing `completedAt` until the user marks complete.

### Task 022 — History Tab

- New History tab: Plan → Templates → History → Settings (Week renamed to Plan).
- Reverse-chronological list of completed, partial, and imported workouts across on-disk weeks; soft-deleted hidden.
- Detail reuses Run/Ride/Strength views via week-scoped mutate.

**Major decisions**
- Scan `weekplan-*.json` via `WeekPlanFileIndex` rather than a separate history index for v1.
- Skipped/planned-only workouts excluded from History.

### Follow-ups after 017–022 (non-blocking)

- **Match dialog** — no Cancel; user must Apply or Create new (intentional for solo use). Easy later change: dismiss → decline.
- **Settings import QA** — UUID imports land on Plan calendar (or match prompt), not Unattached. Unattached is for UUID-less / manual attach / detach. Verify via Plan/History, not only Unattached count.
- **Week export/import** — export/import use embedded strength snapshots only (no `strengthlog-*.json` fallback).
- **History scope** — scans local `weekplan-*.json` only; CloudKit-only weeks appear after a local pull (expected v1).
- **Strength mid-session** — writes `completedValues` while status may still be `.planned` (sync); History correctly excludes until completed/partial/imported.

### Task 023 — Settings and Data Tools

- Last HealthKit import timestamp + iCloud last-sync status in Settings.
- Duplicate import cleanup (confirmation; soft-delete UUID duplicates only).
- Export/import use embedded strength snapshots only.
- Import footer clarifies Plan/History vs Unattached.

**Major decisions**
- Sync/import timestamps in UserDefaults (lightweight; not CloudKit metadata).
- Cleanup never soft-deletes non-import planned workouts.

### Task 024 — Periodized Block Models

- `PeriodizedBlockTemplate` / `PeriodizedBlockWeek` with weekCount 2–12, default Week N names, daySnapshots + optional linkedWeeklyTemplateId.
- JSON + CloudKit (`periodizedBlocks.json` / `PeriodizedBlockTemplate` record).
- Week plan carries `appliedPeriodizedWeekName` / `appliedPeriodizedBlockId` for planner display.

**Major decisions**
- Linking a weekly template snapshots days into the block (independence from later weekly-template edits).
- `manuallyConstructedWeek` legacy decode key accepted; encode uses `daySnapshots`.

### Task 025 — Periodized Block UI

- Templates tab **Blocks** segment: create/edit/rename weeks, link weekly templates, soft-delete.
- Detail preview lists day workouts per block week.

**Major decisions**
- Reuse weekly template list for linking rather than a full inline day builder in v1 (clear week + link covers rest vs template weeks).

### Task 026 — Apply Periodized Blocks

- Apply from Templates swipe or Plan toolbar; conflict scan across full multi-week range before writes.
- Merge / Overwrite / Cancel; new workout IDs; `linkedPeriodizedBlockId` set; week name shown as Plan navigation title.

**Major decisions**
- Start week = currently viewed Plan week (same mental model as weekly template apply).
- Overwrite soft-deletes existing actives per week, matching weekly template overwrite.

### Task 027 — Final Polish and Release Checklist

- Removed unused Core Data `Persistence.swift` + `progressio.xcdatamodeld`.
- Accessibility labels on Plan week navigation and template add.
- HealthKit / iCloud entitlements and usage strings already present in project settings.
- Build succeeds; overhaul task track 001–027 complete.

**Major decisions**
- Release-blocking items from 027 checklist remain manual QA; no known duplicate-HK or template-mutation regressions introduced in this pass.
- Dead `PersistenceController` removed rather than left as scaffold.

### Overhaul complete

Next work is product polish / App Store submission QA per Task 027 checklist (manual).

---

### Task 029 — Reflections & Physical Discomfort

- **Models** — `ActivityReflection`, `WeeklyReflection`, `PhysicalIssue`, `ActivityIssueReport`, `WeeklyIssueReview` as standalone synced entities; `weekKey` = Monday `yyyy-MM-dd`.
- **WeekPlan** — `isWeekComplete` / `weekCompletedAt` (reflections optional).
- **UX** — Activity reflection sheet on any complete path; Complete Week footer with unresolved validation / skip-all; weekly reflection + issue review.
- **Export / History** — Week summary and History rows include reflection data.

**Major decisions**
- Standalone File→CloudKit→SyncingStore pattern (like HealthKit refs), not embedded in week blob, so physical issues can span weeks.
- Session RPE is independent of strength per-lift RPE and of `completedIntensityRPE`.
- One activity reflection per workout; re-complete offers overwrite vs keep.
- Week close treats completed / partial / skipped as resolved; planned and imported must be closed or auto-skipped.

### Task 030 — Reflection Gaps from 029 Review

- **HealthKit complete → reflection** — `attachActualRun` returns the workout ID only when status newly becomes `.completed`. Planner UI (`WeekPlannerView` / unattached sheet) sets `reflectionWorkoutID` so the same activity reflection sheet + overwrite prompt runs as swipe/detail complete. (Match-accept was removed earlier; Unattached attach is the HK complete path.)
- **Overwrite replaces issue reports** — `replaceActivityIssueReport` soft-deletes prior active `ActivityIssueReport`s for the workout before creating a new one; clearing discomfort on overwrite soft-deletes priors without creating a replacement.
- **Orphan cleanup** — Soft-deleting a workout also soft-deletes its `ActivityReflection` and related active reports (`softDeleteReflections`).
- **Weekly issue list (v1)** — Weekly reflection still shows **all active** `PhysicalIssue`s globally (not limited to the current week). Acceptable for v1; tighten later if needed.
- **Tests** — `ReflectionLogicTests` covers WeekKey, unresolved filter, one-reflection upsert/overwrite, report replace, resolve-via-weekly-review, and workout soft-delete cascade.

### Task 031 — Single Strength Path on WeekPlan

- **Source of truth** — planned: `Workout.plannedValues.plannedStrengthRoutineSnapshot`; in-progress/completed: `Workout.completedValues.completedStrengthRoutineSnapshot`.
- **Removed dual path** — `StrengthLogView` and week export no longer read `strengthlog-*.json`.
- **`StrengthLogPersistence`** — migration/legacy only; launch runs a safe orphan-file sweep (delete when snapshot exists or no matching workout).
- **`ExerciseLog` / `SetLog`** — remain UI editing types for `StrengthLogView`; `StrengthLogState` / `PlannedSession` are decode bridges only.

### Task 032 — StairMaster Activity Type

- **`ActivityType.stairMaster`** — planner add + endurance templates; detail UI focuses on time, elevation (ft), level 1–20 (`plannedLevel` / `completedLevel`).
- **Week totals** — StairMaster rolls up by **hours**; elevation caption when present (primary-metric prefs are Task 033).
- **HealthKit** — discovery includes `.stairClimbing` and `.stairs` → `ActivityType.stairMaster` into Unattached (with `UnattachedRun.activityType`). Running still maps to road run. Level is not available from HK; duration (+ optional flights→ft estimate) is imported.

### Task 033 — Primary Metric Preferences

- **Settings → Primary metrics** — per endurance activity (`UserDefaults`, not CloudKit).
- **Defaults:** Road/Trail/Walk → distance; Bike → time; StairMaster → time. StairMaster options: time / elevation / level.
- **Week totals** — roll up by the chosen metric; elevation caption only when elevation is not primary.
- **Detail defaults** — Run/Ride open on Miles vs Time from preference; elevation preference focuses the elevation field. StairMaster focuses elevation when that is primary.

### Task 034 — Strength Set UX Polish

- **`StrengthSetSnapshot.isSkipped`** / **`SetLog.isSkipped`** — decode missing as false; round-trips via completed snapshot on the week plan.
- **Weight autofill** — entering weight on the first non-skipped set copies into later empty, non-skipped sets only (never overwrites typed weights). New sets inherit that weight when present.
- **Skip set** — swipe leading Skip/Unskip; skipped rows styled and excluded from prior-history lift sets; still kept in planned set structure.
- **Reps midpoint** — menu picker highlights midpoint of `repHint` (`8-12` → 10) when reps are empty; does not auto-write until the user picks.

---

## Source File Index

```
progressio/progressio/
├── Models/ActivityMetricPreferences.swift
├── Models/ReflectionModels.swift
├── Models/TemplateSnapshot.swift
├── Services/ReflectionFileStores.swift
├── ViewModels/WeekPlannerViewModel+Reflections.swift
├── Views/WeekPlanner/ActivityReflectionSheet.swift
├── Views/WeekPlanner/WeeklyReflectionSheet.swift
├── Views/WeekPlanner/StairMasterDetailView.swift
├── Views/WeekPlanner/StrengthLogView.swift
└── … (stores, migration through v7; strength files migration-only)
progressio/progressioTests/ReflectionLogicTests.swift
progressio/progressioTests/StrengthSetUXTests.swift
progressio/docs/DataModel.puml
```

---

*Last updated: Task 034 Strength Set UX Polish.*
