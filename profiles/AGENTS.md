# AGENTS.md (profiles)

## Scope
- Reusable modules in `profiles/`.

## Rules
- Any profile change is cross-host by default.
- List impacted hosts before execution.
- Keep module boundaries clear: one profile, one concern.
- Prefer options/flags over host hardcoding.

## Verification
- Validate at least one representative host per impacted profile family.
- For risky profiles (`network`, `zero-trust`, `ai-inference`), include explicit failure/rollback notes.

