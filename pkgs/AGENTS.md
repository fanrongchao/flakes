# AGENTS.md (pkgs)

## Scope
- Custom package definitions and overrides in `pkgs/` and `overlays/`.

## Rules
- Prefer reproducible pinned sources/hashes.
- For version bumps, record:
  - source update
  - hash update reason
  - compatibility notes
- Avoid hidden runtime dependencies outside Nix derivations.

## Verification
- Build updated package derivation.
- Confirm call sites in overlays/hosts remain valid.

