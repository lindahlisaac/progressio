# Cursor Instructions for Progressio

## Project Identity

Progressio is a production-quality iOS training planner for multi-modal endurance athletes.

The app should prioritize planning, templates, and a clean weekly training experience.

The weekly planner is the heart of the app.

## Development Priorities

Favor clean architecture over quick fixes.

Prefer refactoring existing architecture rather than layering new code onto clunky implementations.

Do not duplicate business logic.

Favor reusable SwiftUI components.

Preserve iCloud compatibility.

Preserve migration support.

Maintain stable identifiers.

Keep files reasonably modular.

When implementing new features, prefer extending existing abstractions rather than introducing one-off solutions.

Avoid technical debt whenever practical.

If an implementation conflicts with the architecture documents, prefer updating the implementation rather than working around it.

The documentation contained within the Docs directory should be treated as the source of truth for product behavior.

## Agent Workflow Guidance

Do not attempt to build the entire roadmap in one pass.

Implement one phase or one scoped task at a time.

Before making broad changes, inspect existing models, services, and sync infrastructure.

When changing data models, identify migration requirements before editing production models.

When touching Apple Health import, prioritize idempotency and duplicate prevention.

When touching planner UI, prioritize speed and clarity.

When touching templates, preserve the rule that applied templates create independent copies.

## Non-Negotiable Product Rules

- Planned data and completed data are distinct.
- Completed values must not overwrite planned values.
- Applying a template creates independent workout copies.
- Editing applied workouts must not modify templates.
- Editing templates must not modify previously applied workouts.
- Imported Apple Health workouts must not duplicate on repeated import.
- iCloud sync compatibility must be preserved.
