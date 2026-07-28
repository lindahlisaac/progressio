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

8. **Complete gate** — Status stays **planned** (or prior non-complete) until reflection **Save**. Dismissing the sheet **does not** complete the workout. **Yes.**
9. **Skip reflection** — **Lighter** than full activity reflection: skip reason + optional injury/discomfort link. Not the full feel/sessionRPE performance form unless reuse is trivially shared. **Requiredness:** capture the light skip reflection as part of skip confirm (user should land on it after skip reason); keep it small so it isn’t burdensome. Prefer required light form (Save to finalize skip) to match completion discipline; if Save-dismiss symmetry is awkward, at minimum always present it and persist reason on the workout even if injury section is skipped.

## Strength export (035)

10. **Text export header** — Use **workout title**. No special “Push” program-section grouping.
11. **JSON import** — **Out of scope** for now (export only).

## Replace (041)

12. Soft-delete original + link ids + reason — **Yes.**

## Day notes (039)

13. **One notes field per calendar day** (not AM/PM).
14. UI: **collapsible** under/attached to the day header — discrete disclosure/chevron control; not hidden, not a giant always-open editor.
