# 037 - Injury Hub: Browse, Progress, Resolve

## Objective

Add a dedicated place to view **active** and **resolved** physical issues, inspect progression over time (activity reports + weekly reviews), and **resolve** an injury without needing to be inside the weekly reflection flow.

## Required Context

Read:

- `tasks/NEXT-FEATURES-QUESTIONS.md`
- `Models/ReflectionModels.swift`
- `ViewModels/WeekPlannerViewModel+Reflections.swift`
- `Views/WeekPlanner/WeeklyReflectionSheet.swift` (existing resolve via trend)
- `docs/DataModel.md` (Reflections & Physical Discomfort)

## Current State

- `PhysicalIssue`, `ActivityIssueReport`, `WeeklyIssueReview` exist and sync.
- Create/link from activity reflection; resolve primarily via weekly reflection trend `.resolved`.
- **No** standalone injury list / timeline UI.

## Scope

1. **Injury Hub UI** (Settings entry and/or Templates/History sub-area — prefer **Settings** or a top-level entry under History; pick one and document):
   - Segment or sections: **Active** | **Resolved**
   - Row: body area, side, title, startedAt, optional last report pain/date
2. **Detail / progression:**
   - Chronological list of `ActivityIssueReport` (date, workout title if resolvable, pain, timing, trend)
   - Weekly reviews for that issue (weekKey, weeklyTrend, resultingStatus)
3. **Resolve action** on active issues:
   - Sets `status = .resolved`, `resolvedAt = now`, stampSave
   - Optional short note field if model already has `optionalNotes` (don’t invent a parallel store)
   - Keep ability to resolve from weekly reflection (both paths OK)
4. **Reopen** (optional small): move resolved → active, clear `resolvedAt` — include if cheap.
5. Does not remove weekly reflection issue review; hub is the longitudinal view.
6. Docs update.

## Out of Scope

- Medical advice copy / diagnosis features
- Charts beyond a simple chronological list (v1)
- Changing how reports are created during reflections

## Acceptance Criteria

- [x] User can browse active and resolved injuries.
- [x] User can open an injury and see time-ordered reports/reviews.
- [x] User can resolve from the hub; status persists / syncs.
- [x] App builds.

## Manual QA Checklist

- [ ] Create issue via activity reflection → appears under Active.
- [ ] Complete more sessions with reports → timeline grows.
- [ ] Resolve in hub → moves to Resolved with date.
- [ ] Weekly reflection resolve still works.
