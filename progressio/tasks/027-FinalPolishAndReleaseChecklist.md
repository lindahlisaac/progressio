# 027 - Final Polish and Release Checklist

## Objective

Prepare Progressio for publishing after the core overhaul.

## Required Context

Read all docs files, `ImplementationNotes.md`, and completed task notes.

## Scope

Review and fix release-blocking issues in:

- Planner usability
- Template flows and independence
- Apple Health import reliability (no duplicates, matching works)
- iCloud sync behavior (including strength logs)
- Migration from legacy JSON data
- Empty and error states
- Soft delete behavior
- Week navigation and totals accuracy
- Accessibility basics
- App Store readiness (entitlements, HealthKit usage description, etc.)

Remove dead code where safe: unused `PersistenceController`, dead `hasAttachedRun` if not addressed earlier.

## Manual QA Checklist

### Workouts and planner

- [ ] Create manual workout for each activity type.
- [ ] Week navigation prev/next.
- [ ] Weekly totals accurate (planned vs completed, skipped handling).
- [ ] Drag workout to another day.
- [ ] Copy/paste planned only and with completed values.
- [ ] Skip workout with reason.

### Templates

- [ ] Create strength template; apply to workout; edit workout — template unchanged.
- [ ] Edit template — applied workout unchanged.
- [ ] Create endurance template; apply to day.
- [ ] Create weekly template; apply to empty week.
- [ ] Apply weekly template to non-empty week: merge, overwrite, cancel.
- [ ] Create weekly template from existing week.

### Apple Health

- [ ] Import HealthKit workouts twice — no duplicates.
- [ ] Match import to planned workout — accept: planned preserved.
- [ ] Decline match — ad-hoc imported workout created.

### Sync and migration

- [ ] Migrate from pre-overhaul app data (week plans, templates, strength logs).
- [ ] iCloud sync across devices or simulator accounts.
- [ ] Strength completion syncs across devices.

### Periodized blocks

- [ ] Create and apply 2–12 week block.
- [ ] Conflict detection across full range.
- [ ] Week names display in planner.

## Acceptance Criteria

- The app builds cleanly.
- Core flows stable per checklist.
- No known duplicate Apple Health import issue.
- No known template mutation issue.
- No known planned/completed overwrite issue.
- Release-blocking bugs documented or fixed.
