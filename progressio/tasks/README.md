# Progressio Cursor Task System

This folder contains agent-sized implementation tasks for Progressio.

**Task 001 (audit) is complete.** `ImplementationNotes.md` documents the current architecture discovered in that audit. All tasks below were revised to reflect that reality.

Use these tasks **one at a time**. Do not ask Cursor to implement the entire roadmap in one pass.

## Recommended Workflow

1. Read `000-AgentOperatingRules.md` and `ImplementationNotes.md`.
2. Open the next task file.
3. Tell Cursor: `Read docs/CursorInstructions.md, ImplementationNotes.md, and this task file. Implement only this task. Do not move on to later tasks.`
4. Review the diff.
5. Build and run manual QA from the task checklist.
6. Commit.
7. Move to the next task.

## Roadmap Overview

Tasks are ordered intentionally. Later tasks assume earlier ones are complete.

| Phase | Tasks | Focus |
|-------|-------|-------|
| Foundation | 001–003 | Audit (done), new workout types, migration infrastructure |
| Data migration | 004–005 | Migrate week plans, templates, and strength logs from legacy JSON |
| Sync | 006 | Soft deletes, timestamps, CloudKit payload versioning |
| Wiring | 007–008 | View models + template independence (snapshot-on-apply) |
| Templates | 009–010, 016–017 | Endurance template split, weekly template snapshot fixes, UI refactor |
| Planner UX | 011–015 | Activity types, status indicators, totals, drag, copy/paste |
| Apple Health | 018–020 | Consolidate import paths, UUID dedup, planned matching |
| Sync gap | 021 | Strength log CloudKit sync |
| Navigation | 022–023 | History tab, settings/data tools polish |
| Periodized blocks | 024–026 | Models, UI, apply to calendar |
| Release | 027 | Final polish and QA checklist |
| Subjective data | 028–031 | Reflections, issues, strength single path |
| Next features | 032–041 | StairMaster, metrics, strength UX, reflection gates, injuries, day notes, replace |

## What Changed After Task 001

The original roadmap assumed a greenfield data model refactor. The audit found:

- **`PlannedSession` is the de-facto workout** — not a unified `Workout` type yet.
- **Persistence is JSON + CloudKit**, not Core Data/SwiftData (`PersistenceController` is unused).
- **Strength logs are separate local files** not synced to iCloud.
- **Weekly template apply reuses session UUIDs** — a known bug to fix before new features.
- **Strength templates are linked by name**, not ID — partial live-link risk.
- **Skip workflow already exists** — removed from drag/copy task scope.
- **Weekly templates and template UI partially exist** — later tasks are refactors, not greenfield builds.
- **Two HealthKit import entry points** — consolidated before dedup/matching work.
- **Task 002 was too large** — split into types (002), migration infra (003), week migration (004), template/strength migration (005), and sync metadata (006).

## Task Index

| # | File | Status |
|---|------|--------|
| 000 | `000-AgentOperatingRules.md` | Reference |
| 001 | `001-AuditExistingApp.md` | **Complete** |
| 002 | `002-WorkoutTypesAndMetadata.md` | **Complete** |
| 003 | `003-MigrationInfrastructure.md` | **Complete** |
| 004 | `004-MigrateWeekPlansAndWorkouts.md` | **Complete** |
| 005 | `005-MigrateTemplatesAndStrengthLogs.md` | **Complete** |
| 006 | `006-SyncMetadataAndSoftDeletes.md` | Complete |
| 007 | `007-WireViewModelsToWorkoutModel.md` | Complete |
| 008 | `008-TemplateSnapshotOnApply.md` | **Complete** |
| 009 | `009-EnduranceTemplateModelSplit.md` | **Complete** |
| 010 | `010-WeeklyTemplateSnapshotOnApply.md` | **Complete** |
| 011 | `011-PlannerActivityTypesAndAddFlow.md` | **Complete** |
| 012 | `012-PlannerStatusIndicators.md` | **Complete** |
| 013 | `013-WeeklyTotals.md` | **Complete** |
| 014 | `014-DragWorkoutsBetweenDays.md` | **Complete** |
| 015 | `015-CopyPasteWorkouts.md` | **Complete** |
| 016 | `016-TemplatesUIRefactor.md` | **Complete** |
| 017 | `017-WeeklyTemplatesPolish.md` | **Complete** |
| 018 | `018-ConsolidateHealthKitImportPipeline.md` | **Complete** |
| 019 | `019-AppleHealthUUIDDedup.md` | **Complete** |
| 020 | `020-AppleHealthPlannedMatching.md` | **Complete** |
| 021 | `021-StrengthLogCloudSync.md` | **Complete** |
| 022 | `022-HistoryTab.md` | **Complete** |
| 023 | `023-SettingsAndDataTools.md` | **Complete** |
| 024 | `024-PeriodizedBlockModels.md` | **Complete** |
| 025 | `025-PeriodizedBlockUI.md` | **Complete** |
| 026 | `026-ApplyPeriodizedBlocks.md` | **Complete** |
| 027 | `027-FinalPolishAndReleaseChecklist.md` | **Complete** |
| 028 | `028-SUBJECTIVE-DATA-COLLECTION-ANALYSIS` | **Complete** (design) |
| 029 | `029-subj-data-impl` | **Complete** (impl; gaps → 030) |
| 030 | `030-ReflectionGapsFrom029Review.md` | **Complete** |
| 031 | `031-SingleStrengthPathOnWeekPlan.md` | **Complete** |
| — | `NEXT-FEATURES-QUESTIONS.md` | **Answered** (locked decisions for 032–041) |
| 032 | `032-StairMasterActivityType.md` | **Complete** |
| 033 | `033-PrimaryMetricPreferences.md` | **Complete** |
| 034 | `034-StrengthSetUXPolish.md` | **Complete** |
| 035 | `035-StrengthSummaryAndExport.md` | **Complete** |
| 036 | `036-ReflectionGatedCompletionAndSkip.md` | **Complete** |
| 037 | `037-InjuryHub.md` | **Complete** |
| 038 | `038-HistoryReflectionEditWarning.md` | **Complete** |
| 039 | `039-DayNotes.md` | Pending |
| 040 | `040-TemplatePlannedMileage.md` | Pending |
| 041 | `041-ReplaceWorkoutWithReason.md` | Pending |

## Task File Format

Each task includes:

- Objective
- Required context docs
- Current state (from audit, where relevant)
- Scope
- Out of scope
- Implementation notes
- Acceptance criteria
- Manual QA checklist
