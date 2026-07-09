# 000 - Agent Operating Rules

## Objective

Give Cursor agents consistent rules for working on Progressio.

## Required Context

Read these files before modifying code:

- docs/CursorInstructions.md
- docs/ProductVision.md
- docs/Architecture.md
- docs/DataModel.md
- docs/SyncAndMigration.md
- tasks/ImplementationNotes.md (current codebase map from Task 001)

## Rules

Implement one task at a time.

Do not opportunistically build later roadmap features.

Prefer refactoring over layering new behavior onto clunky old code.

Do not duplicate business logic.

Do not break iCloud sync.

Do not remove migration support.

Do not change public model semantics without updating documentation.

Do not make completed values overwrite planned values.

Do not make applied templates remain live-linked to their source templates.

Every persisted entity must have stable IDs, created timestamps, updated timestamps, and deletion/sync metadata where appropriate.

## Definition of Done

A task is done only when:

- The app builds.
- Existing planner behavior still works.
- New behavior satisfies the task acceptance criteria.
- No unrelated feature was added.
- Any changed data model has a migration path.
- Any changed behavior is reflected in the relevant Docs file if needed.
