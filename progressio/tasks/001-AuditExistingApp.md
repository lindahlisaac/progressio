# 001 - Audit Existing App

**Status: Complete.** Output: `ImplementationNotes.md`.

## Objective

Create a clear implementation map of the current Progressio codebase before refactoring.

## Required Context

Read:

- Docs/ProductVision.md
- Docs/Architecture.md
- Docs/DataModel.md
- Docs/PlannerUX.md
- Docs/AppleHealth.md
- Docs/SyncAndMigration.md

## Scope

Inspect the existing app and identify:

- Current persisted models
- Current workout model structure
- Current template-related code
- Current weekly planner implementation
- Current Apple Health import implementation
- Current iCloud/CloudKit/SwiftData/CoreData sync implementation
- Current migration strategy, if any
- Known duplicate import path
- UI files involved in the planner
- Services involved in HealthKit and sync

Create or update:

- Tasks/ImplementationNotes.md

The notes should include:

- Current architecture summary
- Risk areas
- Suggested refactor sequence
- Files likely to be modified in the next tasks

## Out of Scope

Do not implement new features.

Do not refactor yet.

Do not rename models yet.

## Acceptance Criteria

- A readable ImplementationNotes.md file exists.
- It identifies where planner, models, templates, HealthKit, and sync are currently implemented.
- It lists risks before the data model cleanup begins.
- The app code is not changed except for documentation notes.
