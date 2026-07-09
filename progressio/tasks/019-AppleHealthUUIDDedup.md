# 019 - Apple Health UUID Dedup

## Objective

Fix Apple Health import so the same workout is never stored twice, using HealthKit UUID as the primary dedup key.

## Required Context

Read:

- docs/AppleHealth.md
- docs/DataModel.md
- docs/SyncAndMigration.md
- tasks/ImplementationNotes.md
- tasks/018-ConsolidateHealthKitImportPipeline.md

## Current State (from audit)

- Dedup via `detailSignature` in `WeekPlannerViewModel` (HK UUID preferred, else SHA256 hash).
- Each import creates new `UnattachedRun.id` even when logically duplicate.
- CloudKit sync of unattached runs can resurrect near-duplicates across devices.
- Docs report users still see duplicate imports.

## Scope

- Add `ImportedHealthWorkoutReference` model (or equivalent) tracking `healthKitUUID`
- Before import: skip if UUID already exists in references, attached workouts, or unattached list
- Fallback hash matching only when UUID unavailable
- Set `WorkoutSource.appleHealth` on imported records
- Store import timestamp
- Gracefully handle existing duplicates (dedupe on migration or first import after upgrade)

## Out of Scope

- Matching to planned workouts (Task 020).
- Importing bike/walk/strength from HealthKit (future).
- History UI.

## Implementation Notes

UUID check must run in consolidated pipeline from Task 018.

Persist reference table in JSON + CloudKit sync.

## Acceptance Criteria

- The app builds.
- Import same HealthKit workout twice: only one local record.
- UUID stored on imported workout and reference table.
- `source = appleHealth` on imported records.
- Existing duplicates cleaned or suppressed without data loss.

## Manual QA Checklist

- [ ] Import last 7 days from Settings.
- [ ] Import again: count unchanged.
- [ ] Attach run, then import again: no duplicate unattached entry.
- [ ] Force sync: no duplicate resurrection.
