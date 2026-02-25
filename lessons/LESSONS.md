# Lessons Timeline

## 2026-02-25

### L-20260225-001
- Context: NixOS flake repo with multiple hosts and frequent ops/devops interactions.
- Decision: Adopt auto-inference-first workflow for host targeting and rebuild actions.
- Evidence: local hostname (`rog-laptop`) matches `hosts/rog-laptop`.
- Reusable rule: map `rebuild` to `nixos-rebuild switch --flake /home/frc/flakes#$(hostname)` unless user asks otherwise.
- Promotion: adopted (as prior in root `AGENTS.md`).

