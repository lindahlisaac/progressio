# 021 - Strength Log Cloud Sync

## Objective

Bring strength workout completion data into iCloud sync so it is not lost across devices.

## Required Context

Read:

- docs/SyncAndMigration.md
- docs/DataModel.md
- tasks/ImplementationNotes.md

## Current State (from audit)

- Strength logs stored as `Documents/strengthlog-{sessionID}.json` — **local only, not in CloudKit**.
- `StrengthLogView` reads/writes these files directly.
- Week export/import embeds strength logs in JSON but CloudKit week sync does not include them reliably.

## Scope

Choose one approach (prefer embedding in workout model):

**Option A (preferred):** Store strength completion in `Workout.completedValues.strengthRoutineSnapshot`; sync via existing week plan CloudKit payload.

**Option B:** Add `StrengthLogStore` with CloudKit sync per session ID.

- Migrate existing `strengthlog-*.json` into workout completed/planned snapshots
- Remove or deprecate standalone strength log files after migration
- `StrengthLogView` reads/writes through workout model, not direct file access

## Out of Scope

- Template snapshot on apply (Task 008 — should be done first).
- View model rewire (Task 007 — should be done first).

## Implementation Notes

Embedding in workout keeps week plan as single sync unit — matches current CloudKit architecture.

Ensure completed strength data does not overwrite planned strength snapshot.

## Acceptance Criteria

- The app builds.
- Log strength sets on device A: visible on device B after sync.
- Existing strength log files migrated without data loss.
- No direct `strengthlog-*.json` writes in production path after migration.

## Manual QA Checklist

- [ ] Log strength workout on simulator.
- [ ] Force sync.
- [ ] Second device/simulator account: strength data present.
- [ ] Template-applied workout: planned snapshot and completed log both intact.
