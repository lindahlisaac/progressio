# Next Features — Answered Questions

Source of truth for tasks 032–041. Coding agents must follow these over older guesses in task drafts.

## StairMaster (032)

1. **Levels** — Machine level **1–20** (the machine’s speed/intensity setting). Treat “level” and “speed” as **one field** (`level` / plannedLevel / completedLevel), not two separate metrics.
2. **Elevation** — Normal **feet climbed** (existing elevation gain fields).
3. **Time** — Duration (existing duration fields).
4. **Distance** — Not a primary StairMaster metric; do not emphasize miles for this type.
5. **HealthKit** — **Yes for v1.** If HK returns a StairMaster (or equivalent stair-climber) workout, put it in the discovered / unattached import pipeline like other modalities.

## Primary metric (033)

6. **Per activity type** in Settings — **Yes.**
7. **Defaults:** Road/Trail/Walk → **miles (distance)**; Bike → **time**; StairMaster → **time.**

## Reflection gating (036)

8. **Complete gate** — **Overridden:** reflections are **optional**. Workout completes immediately; reflection sheet can be Skipped/dismissed without answers. (Earlier “Save required to complete” decision reversed.)
9. **Skip reflection** — **Lighter** than full activity reflection: optional reason + optional injury/discomfort. Not the full feel/sessionRPE form. Reason is **not** required.

## Strength export (035)

10. **Text export header** — Use **workout title**. No special “Push” program-section grouping.
11. **JSON import** — **Out of scope** for now (export only).

## Replace (041)

12. Soft-delete original + link ids + reason — **Yes.**

## Day notes (039)

13. **One notes field per calendar day** (not AM/PM).
14. UI: **collapsible** under/attached to the day header — discrete disclosure/chevron control; not hidden, not a giant always-open editor.
