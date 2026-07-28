# 040 - Template Planned Mileage and Endurance Metrics

## Objective

Ensure endurance (and StairMaster) **planned metrics — especially mileage/distance** — are clearly editable in template creation/editing (workout templates and weekly template entries), and that apply-to-calendar copies those values into the workout snapshot.

## Required Context

Read:

- `Models/EnduranceTemplate.swift`
- `Models/WeeklyTemplateWorkoutEntry.swift`
- `Views/Templates/TemplateLibraryScreen.swift`
- `Views/Templates/WeeklyTemplateDetailView.swift`
- Task 032 (StairMaster template fields)

## Current State

- `EnduranceTemplate` already has optional `plannedDistance`, `plannedDuration`, `plannedElevationGain`, etc.
- Create UI exposes free-text Planned Distance / Duration / Elevation / RPE — may be easy to miss or unlabeled as mileage.
- Weekly template entries carry `PlannedValues`; UX for setting miles may be incomplete or inconsistent.

## Scope

1. Audit template create/edit and weekly entry editors for endurance planned distance.
2. Make **mileage/distance** an obvious, labeled field (e.g. “Distance (mi)”) for run/walk/bike templates.
3. For StairMaster templates (after 032): expose time, elevation, levels, speed — not miles-first.
4. Confirm apply paths (`Workout.from`, weekly apply, periodized apply) copy these planned fields.
5. Fix any gap where weekly template entries cannot set distance today.
6. Short docs tweak under Templates.

## Out of Scope

- Primary metric Settings (033) — templates store planned values; Settings only affect logging defaults
- Strength template exercise editor redesign

## Acceptance Criteria

- [ ] User can set mileage/distance when creating/editing an endurance template.
- [ ] Weekly template entries can set planned distance (and StairMaster metrics when applicable).
- [ ] Apply to a week shows those planned values on the workout.
- [ ] App builds.

## Manual QA Checklist

- [ ] Create “Easy 5 mi” template with distance 5 → apply → workout planned distance is 5.
- [ ] Weekly template Tuesday entry distance set → apply week → Tuesday has mileage.
- [ ] StairMaster template fields round-trip if 032 done.
