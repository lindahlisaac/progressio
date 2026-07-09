# Progressio Sync and Migration

## Purpose

The app already has iCloud sync infrastructure in place.

Any data model overhaul must preserve cloud syncing and safely migrate existing data.

This is one of the most important engineering concerns in the project.

## Requirements

The updated models must support:

- Stable IDs for all records
- Schema versioning
- Migration from current models to new models
- Soft deletes or tombstones for CloudKit/iCloud conflict handling
- Created timestamps
- Updated timestamps
- Source fields

## Stable IDs

All persistent records should use stable unique identifiers.

IDs should not be regenerated during sync, migration, copy, or app restart.

Copied workouts must receive new IDs.

Imported HealthKit workouts should preserve their HealthKit UUID in addition to the app's own stable ID.

## Schema Versioning

The app should know which schema version each record belongs to.

This allows future migrations to be explicit and safer.

## Migration

The app currently has existing infrastructure and existing models.

Migration should:

- Preserve existing planned workouts where possible
- Preserve completed workout data where possible
- Preserve templates where possible
- Preserve iCloud sync compatibility
- Avoid destructive changes without a fallback

## Soft Deletes / Tombstones

Cloud-synced models should avoid immediate hard deletion when that could create sync conflicts.

A soft-deleted record should include:

- isDeleted
- deletedAt
- updatedAt

The UI should hide deleted records.

The sync layer should be able to propagate deletions safely.

## Conflict Handling

When multiple devices modify data, updatedAt should help determine which record is newer.

Soft-deleted records (tombstones) remain in sync payloads. When one copy is deleted and the other is not, the record with the newer `updatedAt` wins unless that would resurrect a deleted record — tombstones block resurrection without an explicit undelete.

The app should avoid data loss wherever possible.

For workouts with both planned and completed values, conflict resolution should avoid overwriting one side of the data accidentally.

## Source Field

Persistent objects should record where they came from when relevant.

Supported sources:

- Manual
- Template
- Apple Health

## iCloud Safety Rules

- Do not break sync compatibility during refactors.
- Do not change IDs unnecessarily.
- Do not hard-delete records that may still exist on another device unless the sync layer supports that safely.
- Do not overwrite planned data with imported data.
- Do not allow HealthKit imports to create duplicate records.
