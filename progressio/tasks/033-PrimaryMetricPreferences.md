# 033 - Primary Metric Preferences

## Objective

Let the user choose a default **primary metric** per activity type in Settings. That metric drives the week-view summary row for that type and the default input focus when opening an endurance workout to log effort.

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md` (Q5–Q7)
- `Views/Settings/SettingsView.swift`
- `Models/WeekTotals.swift`
- `Views/WeekPlanner/WeekPlannerView.swift` (weekly totals section)
- `Views/WeekPlanner/RunDetailView.swift`, `RideDetailView.swift`
- Task 032 StairMaster fields (should land first or in parallel with care)

## Decisions (locked — see `NEXT-FEATURES-QUESTIONS.md`)

- Per activity type in Settings — **yes**.
- Defaults: Road/Trail/Walk → **distance (miles)**; Bike → **time**; StairMaster → **time**.
- StairMaster primary options should include time / elevation / level (not miles).

## Current State

- No stored metric preference. Detail UIs use ephemeral `EffortUnit` (Miles | Time), defaulting to miles every open.
- Week totals hard-code miles for runs/walk; bike switches to hours only when all distances are zero.

## Scope

1. Persist preferences (UserDefaults is fine for v1 solo settings; document choice):
   - Map `ActivityType` → primary metric enum (`distance`, `duration`, `elevation`, `level` for StairMaster).
2. Settings UI: section “Primary metrics” with a row/picker per endurance activity type (exclude strength).
3. Apply locked defaults above when no preference is stored.
4. `WeekTotals` / week summary UI: display the configured primary metric for each type (keep elevation as secondary caption when useful and not primary).
5. Opening Run/Ride/StairMaster detail: default the effort unit / focused field to that activity’s primary metric; still allow switching for the session.
6. Docs: `ImplementationNotes.md`, brief Settings note.

## Out of Scope

- Changing reflection session RPE
- Per-workout override persisted as a field (session UI switch only)
- Imperial/metric unit system overhaul

## Implementation Notes

- Prefer a small `PrimaryMetric` / `ActivityMetricPreferenceStore` rather than scattering UserDefaults keys.
- Week summary must stay readable with mixed types in one week.
- If 032 not merged yet, implement for existing types and leave StairMaster hook obvious.

## Acceptance Criteria

- [x] Settings can set primary metric per endurance activity.
- [x] Week summary uses those preferences.
- [x] Opening a workout defaults input to that metric.
- [x] Preferences survive relaunch.
- [x] App builds.

## Manual QA Checklist

- [ ] Set Road Run → Time; week summary shows hours/min for road runs.
- [ ] Open a road run → time field is the default entry mode.
- [ ] Set Bike → Miles; summary and detail follow.
- [ ] Change preference mid-week → summary updates on next render.
