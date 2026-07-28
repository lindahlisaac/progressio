# 038 - History Reflections View and Edit Warning

## Objective

Make activity (and weekly, if already on the week) reflections first-class in History: view details and edit with a **soft warning** that reflections should only be amended for objective mistakes, not revised feelings after the fact.

## Required Context

Read:

- `Views/History/HistoryView.swift`
- `Views/WeekPlanner/ActivityReflectionSheet.swift`
- `ViewModels/WeekPlannerViewModel+Reflections.swift`
- Task 036 (completion gating) — edit paths should not bypass gates awkwardly

## Current State

- History rows may show `feel · sRPE`.
- Editing happens by re-opening workout UI / reflection overwrite alert (“overwrite vs keep”) — not History-specific, no amendment philosophy warning.

## Scope

1. History row or detail: clear reflection summary; affordance to **View / Edit reflection**.
2. Before editing an existing reflection, present a soft warning (alert or inline):
   - Reflections capture feelings **at completion time**.
   - Amend only for objective errors (wrong tap, typo), not because assessment changed later.
   - Actions: **Edit anyway** / **Cancel**
3. Edit uses existing sheet + save/overwrite plumbing; stamp `updatedAt` as today.
4. If 036 adds skip reflections into History, same warning applies.
5. Optional: show weekly reflection when viewing a week context from History — only if natural; don’t block the task.
6. Docs: short note in ImplementationNotes.

## Out of Scope

- Locking reflections permanently (hard immutability)
- Analytics on amendment rate

## Acceptance Criteria

- [x] History surfaces reflection details beyond a one-line feel chip.
- [x] Edit path shows the soft warning before mutation.
- [x] Cancel leaves reflection unchanged.
- [x] App builds.

## Manual QA Checklist

- [ ] Open History item with reflection → view values.
- [ ] Edit → warning → Cancel → unchanged.
- [ ] Edit → warning → Edit anyway → save → values update.
