# AGENTS.md (hosts)

## Scope
- Host-local changes under `hosts/<name>/`.

## Rules
- Default host target is current `hostname`.
- If editing `hosts/<x>/`, treat as single-host change unless profile dependencies prove wider impact.
- Keep hardware-specific logic in host scope; avoid leaking to shared profiles.

## Verification
- Build/eval target host config first.
- Validate host-critical services affected by change.
- Provide host-specific rollback step.

