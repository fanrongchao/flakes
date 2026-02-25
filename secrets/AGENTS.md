# AGENTS.md (secrets)

## Scope
- Secret source files under `secrets/` and sops workflows.

## Rules
- Only sops-encrypted files are allowed.
- Never output or store plaintext secret values in repo files.
- Respect `.sops.yaml` creation rules and recipient coverage.
- If secret rotation is needed, describe impact and restart/reload implications.

## Verification
- Confirm secret references from Nix modules remain path-correct.
- Confirm no plaintext secret file was introduced.

