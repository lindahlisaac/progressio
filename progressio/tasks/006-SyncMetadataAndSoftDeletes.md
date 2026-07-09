# 006 - Sync Metadata and Soft Deletes

## Objective

Update the JSON + CloudKit persistence layer to support schema versioning, full timestamps, and soft deletes.

## Required Context

Read:

- docs/SyncAndMigration.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Stores in `Storage.swift`, `CloudKitStores.swift`, `SyncingStores.swift`.
- Only `updatedAt` and `etag` exist; no `createdAt`, `isDeleted`, or `schemaVersion`.
- Deletes are hard removes from arrays — CloudKit orphan records accumulate.
- CloudKit reads use blocking semaphores on the calling thread.
- Conflict resolution: last-writer-wins on `updatedAt` per record.

## Scope

- Add `createdAt`, `isDeleted`, `deletedAt`, `schemaVersion` to all synced entity types (post-migration shapes from Tasks 004–005)
- Update `SyncingStores` merge logic to respect soft deletes (tombstoned records win over missing)
- Update delete operations in view models to soft-delete instead of array removal (UI hides deleted records)
- Include `schemaVersion` in CloudKit JSON payloads
- Document known limitation: full CloudKit orphan cleanup may require a follow-up; implement delete propagation for soft-deleted records where feasible

## Out of Scope

- View model rewiring to new Workout type (Task 007).
- Strength log CloudKit sync (Task 021).
- Rewriting CloudKit to async/await (optional improvement, not required).
- Removing unused `Persistence.swift` / Core Data scaffold.

## Implementation Notes

Soft delete: set `isDeleted = true`, `deletedAt = now`, `updatedAt = now`; keep record in store payload for sync propagation.

Merge: if remote is deleted and local is not, prefer newer `updatedAt`; never resurrect without explicit undelete.

Preserve backward compatibility reading old payloads without metadata fields (default `isDeleted = false`).

**Cross-device / CloudKit:** Devices on different metadata schema versions must sync without crash. Missing `createdAt`, `schemaVersion`, or soft-delete fields on remote payloads default safely. Tombstones from a migrated device must propagate to devices still reading legacy-shaped records.

## Acceptance Criteria

- The app builds.
- Deleting a template marks it deleted without removing from sync payload immediately.
- Deleted records do not appear in UI lists.
- `createdAt` is set on new records and preserved on existing after migration.
- CloudKit save/load includes `schemaVersion`.
- iCloud sync still functions for templates, week plans, weekly templates, and unattached runs.
- Two devices: soft-delete on Device A hides record on Device B after sync.
- Two devices: Device A with full metadata syncs to Device B with legacy-shaped remote records — no crash, defaults applied.

## Manual QA Checklist

- [ ] Delete strength template: disappears from list, reappears after sync from device that hasn't deleted (tombstone wins).
- [ ] Create new template: has createdAt.
- [ ] Force sync in Settings: no crash, data intact.
- [ ] **Two devices:** Delete template on A, sync on B — template hidden on B (tombstone wins).
- [ ] **Two devices:** Create record on A (with metadata), sync to B — record appears with sensible defaults for any missing fields.
