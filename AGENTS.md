# AGENTS.md (Repo Root)

## Mission
- This repo is NixOS infra + agent collaboration code.
- Priorities: correctness, reproducibility, rollback safety, low-friction ops.

## Repo Map
- `hosts/`: host-specific system config.
- `profiles/`: reusable cross-host modules.
- `clusters/`: Kubernetes resources and platform manifests.
- `pkgs/`: custom packages/overrides.
- `secrets/`: sops-encrypted secret sources only.
- `lessons/`: accumulated lessons and machine-readable patterns.

## NixOS Priors (Auto-Inference First)
- Assume execution environment is NixOS unless proven otherwise.
- Infer target host from `hostname`.
- If `hosts/<hostname>/` exists, default flake target is `.#<hostname>`.
- If user says `rebuild`, default to system switch for current host:
  - `sudo nixos-rebuild switch --flake /home/frc/flakes#$(hostname)`
- Prefer `nix shell` / `nix run` / flake packages for tooling.
- Avoid ad-hoc global installs unless user explicitly requests a non-Nix path.

## Safety Gates (Default Conservative)
- Any `rebuild/deploy/secret/network` task must include:
  - impact scope
  - likely failure modes
  - rollback path
- Do preflight checks before high-risk execution.
- Never suggest plaintext secret workflows for files under `secrets/` or `clusters/**/*.sops.yaml`.

## Execution Contract (Per Task Output)
- Scope changed (`host/profile/cluster/pkg`).
- Commands planned/executed.
- Verification checklist.
- Rollback command/path.
- `Lesson candidate` (if any).

## Lesson Protocol
- Add new facts to `lessons/LESSONS.md`.
- Normalize reusable rules in `lessons/patterns.yaml`.
- Promote from lesson to prior when:
  - repeated >= 2 times, or
  - high-risk scenario succeeds once and is generalizable.
- Deprecate outdated patterns; do not silently delete history.

