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

**Navigation** (`ContentView.swift`): three tabs — Week (planner), Templates, Settings. No History tab yet.

**Strength session logs** are stored separately as per-session JSON files in `Documents/` (`strengthlog-{sessionID}.json`). These are **not synced to CloudKit**.

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
| `StrengthLogState` | Completed strength log (file-backed) | `sessionID: UUID` | `updatedAt` optional | `etag` optional |

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

**Planned vs completed (strength):** Split across two stores. Template targets live in `StrengthTemplate`; logged sets live in a **separate file** (`strengthlog-{id}.json`) via `StrengthLogView`. No explicit planned snapshot on the session.

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
| Import orchestration | `WeekPlannerViewModel.importUnattachedRuns`, `dedupeUnattachedRuns` |
| Manual import trigger | `Views/Settings/SettingsView.swift` ("Import last 7 days") |
| Background observer trigger | `WeekPlannerView.startHealthKitObserverIfNeeded` |
| Attach to planned session | `WeekPlannerViewModel.attachActualRun`, `UnattachedRunsView` |

**Import flow:**

1. `HealthKitManager.fetchRecentRuns` queries running workouts, maps to `UnattachedRun` with `RunDetailData.hkWorkoutUUID`.
2. Runs passed to `importUnattachedRuns`, which dedupes via `detailSignature` (HK UUID preferred, else SHA256 hash of date/title/distance/duration/HR/category).
3. User attaches run to a day/session; `actualRun` populated, status set to completed.
4. If no matching planned run, a new session is appended as completed with note "Imported from HealthKit".

**Known duplicate import paths (two entry points, one dedupe layer):**

```
Path A: SettingsView → fetchRecentRuns (7 days) → importUnattachedRuns
Path B: WeekPlannerView.onAppear → startObservingRuns → fetchRecentRuns (3 days) → importUnattachedRuns
```

Both paths call the same dedupe logic, but:

- `hasAttachedRun(with:)` exists in `WeekPlannerViewModel` but is **never called** — dead code intended for dedup at attach time.
- Observer fires on every HealthKit update and re-fetches; dedupe should prevent list growth but users report duplicates (per `docs/AppleHealth.md`).
- Each import creates a **new** `UnattachedRun.id` even when deduped at list level; CloudKit sync of unattached runs could resurrect duplicates across devices if signatures differ slightly.
- No user confirmation before applying import to planned workout (docs require prompt).
- No AM/PM matching logic.
- Only **running** workouts imported; no cycling/walking.
- Strength logs and HK references are not modeled as `ImportedHealthWorkoutReference`.

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

- Strength logs (`strengthlog-*.json` in Documents root, not under `progressio/`)
- Core Data (`Persistence.swift` / `progressio.xcdatamodeld`) — unused boilerplate

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

### Next up — Task 017

- Weekly templates polish (then HealthKit 018–020).

---

## Files Likely Modified in Next Tasks

### Task 002 (Workout Types and Metadata)

| File | Reason |
|------|--------|
| New `Models/` files (recommended) | `Workout`, value types, enums, `LegacySessionMapper` |
| `Models/Models.swift` | Unchanged legacy types remain in use until Task 007 |

### Task 003 (Migration Infrastructure)

| File | Reason |
|------|--------|
| New `Services/Migration/` files | Migration runner, version gate, step protocol |

### Tasks 004–006 (migration + sync metadata)

| File | Reason |
|------|--------|
| `Services/Storage.swift` | Dual-read / migrated file formats |
| `Services/SyncingStores.swift` | Merge logic for metadata and soft deletes |
| `Services/CloudKitStores.swift` | Payload encoding, legacy CloudKit decode |

### Task 007+ (likely touch)

| File | Reason |
|------|--------|
| `Models/Models.swift` | `DayPlan` / `WeekPlan` switch to `Workout` |
| `ViewModels/WeekPlannerViewModel.swift` | Adapt to new workout type |
| `ViewModels/TemplateLibraryViewModel.swift` | Template metadata fields |
| `Views/WeekPlanner/WeekPlannerView.swift` | Session display, add-workout flow |
| `Views/WeekPlanner/RunDetailView.swift` | Planned/completed field mapping |
| `Views/WeekPlanner/RideDetailView.swift` | Same |
| `Views/WeekPlanner/StrengthLogView.swift` | Snapshot vs template link |
| `Views/Templates/TemplateLibraryScreen.swift` | Template types UI |
| `Views/Templates/WeeklyTemplate*.swift` | Weekly template structure |
| `Services/HealthKitManager.swift` | Import model alignment (Task 018+) |
| `Views/Settings/SettingsView.swift` | Import/sync settings |
| `App/ContentView.swift` | History tab (Task 022) |

### Candidates for removal or cleanup (later)

| File | Reason |
|------|--------|
| `Services/Persistence.swift` | Unused Core Data scaffold |
| `progressio.xcdatamodeld` | Unused unless pivoting to Core Data |

---

## Source File Index

```
progressio/progressio/
├── App/
│   ├── progressioApp.swift          # App entry (no persistence wiring)
│   └── ContentView.swift            # Tab shell
├── Models/
│   └── Models.swift                 # All domain types
├── ViewModels/
│   ├── WeekPlannerViewModel.swift   # Planner + import + sync orchestration
│   └── TemplateLibraryViewModel.swift
├── Services/
│   ├── Storage.swift                # File stores + protocols
│   ├── CloudKitStores.swift         # CloudKit backing
│   ├── SyncingStores.swift          # Local/cloud merge
│   ├── HealthKitManager.swift       # HK read + observer
│   └── Persistence.swift            # Unused Core Data
└── Views/
    ├── WeekPlanner/                 # Planner UI (6 files)
    ├── Templates/                   # Template library UI (3 files)
    ├── Reports/WeeklyReportView.swift
    └── Settings/SettingsView.swift
```

---

*Last updated: Task 016 complete.*
