# 023 - Settings and Data Tools

## Objective

Polish Settings for sync, import, and data tools — building on what already exists.

## Required Context

Read:

- docs/ProductVision.md
- docs/SyncAndMigration.md
- docs/AppleHealth.md
- tasks/ImplementationNotes.md

## Current State (from audit)

`SettingsView` already has:

- HealthKit authorization request
- Manual "Import last 7 days of runs"
- Clear imported runs
- Force CloudKit sync
- Export current week JSON + share
- Import week from file

Missing:

- Last import timestamp
- Sync status detail
- Duplicate cleanup tool
- "Coming soon" placeholder section

## Scope

Polish existing Settings (not greenfield):

- Show last HealthKit import date/time
- Show iCloud sync status (last sync time, error if any)
- Relocate HealthKit import trigger here (consolidated pipeline from Task 018)
- Safe duplicate cleanup action for imported workouts (with confirmation)
- Remove or update "Coming soon" placeholders for shipped features
- Keep export/import week tools (already implemented)

## Out of Scope

- History list (Task 022).
- Advanced analytics.
- Destructive reset without confirmation.

## Implementation Notes

Export/import already works — document in UI, don't rebuild.

Duplicate cleanup uses reference table from Task 019.

## Acceptance Criteria

- The app builds.
- Last import date visible.
- Sync status visible.
- Import trigger works via consolidated pipeline.
- Duplicate cleanup requires confirmation and is non-destructive to planned data.
- Export/import week still works.

## Manual QA Checklist

- [ ] Import runs: last import date updates.
- [ ] Sync now: status message updates.
- [ ] Export week + share: file generated.
- [ ] Import week from file: week restored.
- [ ] Duplicate cleanup: only removes true duplicates.
