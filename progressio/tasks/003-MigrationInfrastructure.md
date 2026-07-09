# 003 - Migration Infrastructure

## Objective

Add a migration runner and version gate so legacy JSON data can be safely transformed in later tasks.

## Required Context

Read:

- docs/SyncAndMigration.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- **No migration strategy exists.** Stores decode legacy `Codable` structs directly.
- Persisted files: `templates.json`, `weeklyTemplates.json`, `unattachedRuns.json`, `weekplan-*.json`, `strengthlog-*.json`.
- CloudKit stores opaque JSON payloads with no schema version field.

## Scope

Implement:

- `MigrationRunner` (or equivalent) invoked on app launch before stores load data
- A persisted app data version marker (e.g. `dataVersion.json` or UserDefaults key)
- Legacy decoders that can read current on-disk JSON shapes without crashing
- Migration step protocol (`func migrate(from: Int) throws`) for incremental upgrades
- Logging for migration success/failure

Register migration steps as stubs for Tasks 004–005 (empty or no-op until those tasks fill them in).

## Out of Scope

- Do not perform actual data transformation yet (Tasks 004–005).
- Do not change CloudKit record types yet.
- Do not remove legacy model types.

## Implementation Notes

Migration must be idempotent — safe to run multiple times.

Back up or write to new filenames before destructive transforms (Tasks 004–005 will use this).

CloudKit payloads will need version awareness in Task 006; this task only sets up local file migration infrastructure.

## Acceptance Criteria

- The app builds.
- Migration runner executes on launch without changing user-visible behavior.
- Existing data loads correctly when no migration is needed.
- Migration version is persisted and readable on next launch.

## Manual QA Checklist

- [ ] Fresh install: app works, migration version set.
- [ ] Existing install with week data: app works, no data loss.
- [ ] Re-launch: migration does not re-run destructively.
