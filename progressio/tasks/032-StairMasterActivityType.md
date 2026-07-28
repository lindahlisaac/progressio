# 032 - StairMaster Activity Type

## Objective

Add StairMaster as a first-class endurance activity with planned/completed **time**, **elevation (ft)**, and **machine level (1–20)**, plus HealthKit discovery when stair-climber workouts appear — without breaking existing Codable decoding.

## Decisions (locked — see `NEXT-FEATURES-QUESTIONS.md`)

- **Level** = machine speed/intensity **1–20** (single field). Do **not** add a separate speed metric.
- **Elevation** = feet climbed (reuse elevation gain fields).
- **Time** = duration fields.
- **Distance / miles** — not emphasized for StairMaster.
- **HealthKit** — if found, land in discovered / unattached import pipeline (v1).

## Required Context

Read:

- `docs/CursorInstructions.md`
- `docs/DataModel.md`
- `docs/DataModel.puml`
- `tasks/ImplementationNotes.md`
- `tasks/NEXT-FEATURES-QUESTIONS.md`
- `Models/WorkoutEnums.swift`, `Models/WorkoutValues.swift`, `Models/EnduranceTemplate.swift`
- `Views/WeekPlanner/RideDetailView.swift`, `RunDetailView.swift`, `WeekPlannerView.swift`
- `Models/WeekTotals.swift`
- HealthKit import / candidate mapping (`HealthKit*`, `UnattachedRun`, import pipeline)

## Current State

- `ActivityType`: roadRun, trailRun, walk, bike, strength only.
- Endurance metrics: distance / duration / elevation / RPE as optional strings. **No level field.**
- Detail routing: strength → StrengthLogView; run-family → RunDetailView; else → RideDetailView (bike).
- Week totals: miles for runs/walk; bike mi-or-hours heuristic; elevation caption when present.
- HK import oriented toward runs / bike-like paths — stair climber mapping likely missing.

## Scope

1. Add `ActivityType.stairMaster` (display **“StairMaster”** consistently).
2. Include in `plannerAddTypes` and `enduranceTemplateTypes`.
3. Extend `PlannedValues` / `CompletedValues` / `EnduranceTemplate` with optional:
   - `plannedLevel` / `completedLevel` (String? or small Int? — prefer String? for consistency with other metrics, validate 1–20 in UI).
   - Reuse duration + elevation gain fields for time and feet.
4. Decode with `decodeIfPresent` so old week JSON remains valid.
5. Detail UI dedicated to StairMaster (or specialized Ride-like screen): **Time, Elevation (ft), Level (1–20)** — not miles-first.
6. Planner row / History summary: show time + level and/or elevation as appropriate.
7. `WeekTotals`: StairMaster rollup defaults to **time**; elevation caption when present (033 may refine).
8. Icons + `sessionKind` / row tint (cycle-like or distinct).
9. **HealthKit:** map stair-climber / stairMaster HK workout types into the existing discovery → unattached / match pipeline with `ActivityType.stairMaster` when identifiable. If HK type is ambiguous, document mapping choice in ImplementationNotes.
10. Update `DataModel.md`, `DataModel.puml`, `ImplementationNotes.md`.

## Out of Scope

- Primary metric Settings (Task 033)
- Separate “speed” field
- Reflections / replace workout

## Implementation Notes

- Preserve legacy `SessionKind` bridge carefully.
- Do not store level in `plannedDistance`.
- Template apply must copy level + duration + elevation via `Workout.from(template:)`.

## Acceptance Criteria

- [x] App builds; existing weeks decode.
- [x] User can add StairMaster from planner.
- [x] Can enter planned/completed time, elevation (ft), level 1–20.
- [x] Endurance template supports StairMaster + those fields.
- [x] Week totals include StairMaster without breaking other modalities.
- [x] HK stair-climber workouts appear in discovered/unattached flow when present.
- [x] Docs updated.

## Manual QA Checklist

- [ ] Add StairMaster → edit time/elevation/level → persist / sync.
- [ ] Old week without new keys still loads.
- [ ] Template apply copies StairMaster planned values.
- [ ] (If available) HK stair workout shows up in discovery.
