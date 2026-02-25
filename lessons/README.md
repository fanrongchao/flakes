# lessons

This folder stores durable learnings from agent interactions.

## Files
- `LESSONS.md`: append-only human-readable timeline.
- `patterns.yaml`: machine-readable reusable rules.

## Lifecycle
1. Capture: write a new lesson in `LESSONS.md`.
2. Normalize: add/update item in `patterns.yaml`.
3. Promote: upgrade `kind: lesson` to `kind: prior` when repeated or high-value.
4. Deprecate: mark stale rules as `promotion: deprecated` with reason.

## Promotion defaults
- Promote when repeated >= 2 times.
- Or promote after one high-risk successful reusable decision.

