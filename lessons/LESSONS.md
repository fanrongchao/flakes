# Lessons Timeline

## 2026-02-25

### L-20260225-001
- Context: NixOS flake repo with multiple hosts and frequent ops/devops interactions.
- Decision: Adopt auto-inference-first workflow for host targeting and rebuild actions.
- Evidence: local hostname (`rog-laptop`) matches `hosts/rog-laptop`.
- Reusable rule: map `rebuild` to `nixos-rebuild switch --flake /home/frc/flakes#$(hostname)` unless user asks otherwise.
- Promotion: adopted (as prior in root `AGENTS.md`).

## 2026-02-26

### L-20260226-001
- Context: system-level install via `nixos-rebuild switch` on `rog-laptop`.
- Decision: run `nixos-rebuild switch` with `sudo` by default for host switch operations.
- Evidence: non-sudo run completed builds but failed at profile activation with permission denied on `/nix/var/nix/profiles/system-*`.
- Reusable rule: use `sudo nixos-rebuild switch --flake /home/frc/flakes#$(hostname)` unless user explicitly asks not to.
- Promotion: adopted (high-risk and generalizable).

### L-20260226-002
- Context: OpenClaw gateway autostart service was first added under `users/frc/home.nix`.
- Decision: move reusable user-service definitions into `profiles/` and import from target host modules.
- Evidence: profile placement keeps host composition explicit and avoids user file bloat for infra capabilities.
- Reusable rule: place infra-style Home Manager services in `profiles/<capability>.nix`; wire via `hosts/<host>/default.nix` imports.
- Promotion: adopted (generalizable repo structure rule).
