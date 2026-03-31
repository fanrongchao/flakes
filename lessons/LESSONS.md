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

## 2026-02-27

### L-20260227-001
- Context: `openclaw-gateway` service on `pve-dev-01` kept restarting after host import.
- Decision: override service ExecStart with `--allow-unconfigured` for first-boot web access.
- Evidence: user journal showed repeated `Missing config. Run \`openclaw setup\` ... (or pass --allow-unconfigured)` and stabilized immediately after switch.
- Reusable rule: when enabling OpenClaw gateway on a fresh host, include `--allow-unconfigured` (or pre-seed config) to avoid restart loops.
- Promotion: candidate (needs another host confirmation).

## 2026-03-31

### L-20260331-001
- Context: packaging OpenAI Codex for the `m5-air` nix-darwin host inside this flake.
- Decision: package Codex from official GitHub release tarballs instead of the older npm prebuilt layout.
- Evidence: latest stable release `0.117.0` is published on GitHub Releases with per-platform tarballs, and the Darwin tarball contains a standalone `codex` binary at the archive root.
- Reusable rule: when updating Codex in this repo, prefer GitHub release assets keyed by host platform and pin the release SHA256 from the official release metadata.
- Promotion: candidate (first confirmation in this repo).

### L-20260331-002
- Context: enabling passwordless sudo on the `m5-air` nix-darwin host.
- Decision: use `security.sudo.extraConfig` on nix-darwin and validate with `darwin-rebuild build` before `darwin-rebuild switch`.
- Evidence: `security.sudo.extraRules` failed evaluation on nix-darwin, while `security.sudo.extraConfig = ''frc ALL=(ALL) NOPASSWD: ALL'';` built successfully and passed `sudo -n true`.
- Reusable rule: for nix-darwin sudo policy changes, prefer `security.sudo.extraConfig`, do a build preflight first, then verify with `sudo -n`.
- Promotion: adopted (high-risk and generalizable).

### L-20260331-003
- Context: granting the local `m5-air` machine SSH access to the `xfa` account on `ai-server`.
- Decision: add the local machine public key directly to `users.users.xfa.openssh.authorizedKeys.keys` in the target host module and verify with `nix eval` before remote deployment.
- Evidence: the local public key from `~/.ssh/id_ed25519_github.pub` appeared in `nixosConfigurations.ai-server.config.users.users.xfa.openssh.authorizedKeys.keys` immediately after the config edit.
- Reusable rule: for repo-managed host access, add new machine SSH public keys in the target host's `authorizedKeys` list and verify the evaluated list before asking the remote host to pull and switch.
- Promotion: candidate (needs another host confirmation).
