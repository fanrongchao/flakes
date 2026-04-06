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

## 2026-04-06

### L-20260406-001
- Context: replacing an external DERP relay with one hosted directly on `ai-server`, which already fronts `headscale` through HAProxy and Caddy.
- Decision: enable Headscale's embedded DERP server, keep `automatically_add_embedded_derp_region = false`, publish a dedicated `derp.zhsjf.cn` Caddy vhost to the same local `127.0.0.1:8080` listener, and advertise the custom region via `/etc/headscale/derp.yaml`.
- Evidence: `nixos-rebuild switch --flake ~/flakes#ai-server` succeeded on `ai-server`; server-side `curl --resolve derp.zhsjf.cn:8443:127.0.0.1 https://derp.zhsjf.cn:8443/derp` returned `HTTP/2 426`; local `tailscale debug derp 902` reported `Successfully established a DERP connection with node "derp.zhsjf.cn"`.
- Reusable rule: when a Headscale host already sits behind repo-managed HAProxy and Caddy ingress, prefer embedded DERP plus a dedicated hostname/vhost over a separate standalone DERP service; treat public UDP `3478` forwarding as an external gateway dependency to verify separately.
- Promotion: candidate (first confirmation in this repo).

### L-20260406-002
- Context: `ai-server` runs Headscale embedded DERP/STUN and Mihomo TUN on the same Linux host.
- Decision: add a host-level policy routing bypass for the `headscale` system user instead of trying to solve STUN replies inside Mihomo YAML.
- Evidence: before the bypass, `tcpdump` showed inbound `124.64.23.154:* > 192.168.3.111.3478` and outbound `198.18.0.1.3478 > 124.64.23.154:*`, and `tailscale debug derp 902` warned `did not return a IPv4 STUN response`; after deploying the `headscale-derp-route-bypass` service, `ip rule show` included `uidrange 995-995 lookup main`, `tailscale debug derp 902` returned `Node "derp.zhsjf.cn" returned IPv4 STUN response`, and `tailscale netcheck` selected `cn-ai-server` as nearest DERP.
- Reusable rule: when a Linux host runs both Headscale embedded DERP/STUN and Mihomo TUN with auto-route enabled, bypass Mihomo for the `headscale` service user with policy routing so STUN replies leave through the real uplink.
- Promotion: adopted (high-risk and generalizable).

### L-20260406-003
- Context: shared zero-trust and proxy profiles started accumulating deployment-specific domains, public IPs, SNI host lists, and proxy-group names while `ai-server` and the local Mihomo setup kept evolving.
- Decision: keep reusable profiles generic and inject site-owned values from host modules or explicit CLI/script parameters instead of hardcoding them in shared profiles.
- Evidence: moved `hs.zhsjf.cn`, `derp.zhsjf.cn`, `218.11.1.14`, HAProxy SNI host lists, Caddy virtual hosts, `jp-vultr`, `BosLife`, and custom antigravity rules out of shared profiles and into `hosts/ai-server/default.nix`; `nix eval .#nixosConfigurations.ai-server.config.system.build.toplevel.drvPath` continued to succeed after the refactor.
- Reusable rule: if a value can change per deployment site or per operator preference, model it as a host-level option or CLI/script parameter; do not treat it as a shared-profile constant.
- Promotion: adopted (repeated and high-leverage).

### L-20260406-004
- Context: local Codex connectivity still dropped when macOS system proxy was turned off, even after Tailscale, DERP, rule mode, and Mihomo TUN coexistence had been repaired.
- Decision: inspect Mihomo controller connection metadata before changing more TUN/rule logic, to confirm whether the application is actually entering via transparent TUN or via a local proxy listener.
- Evidence: live controller connections for `chat.openai.com`, `chatgpt.com`, and `api.anthropic.com` all showed `sourceIP = 127.0.0.1` and `inboundName = DEFAULT-MIXED`, which explained why the current Codex desktop session still depended on system proxy even though Tailscale and Clash routing were healthy.
- Reusable rule: when local app connectivity changes with system-proxy toggles, verify the actual Mihomo inbound path first; do not assume the app is already traveling through TUN.
- Promotion: candidate (useful locally, needs another confirmation).

### L-20260406-005
- Context: `ai-server` needs site-specific Headscale, tailnet, and DERP values in zero-trust, ingress, and Mihomo egress config, but those values will migrate over time and must not erase the working DERP/STUN route bypass.
- Decision: keep `headscale-derp-route-bypass` in `zero-trust-control-plane.nix`, and fan site-owned `headscale/tailnet/derp` values out from a single host-owned definition into zero-trust, ingress, HAProxy SNI, and Mihomo egress options.
- Evidence: `hosts/ai-server/default.nix` now derives `networkIngressProxy.virtualHosts`, `ingressHaproxySni.tlsServerNames`, `zeroTrustControlPlane.derp`, and `mihomoEgress.tailscale*` settings from one site parameter block, while `profiles/zero-trust-control-plane.nix` still owns the `headscale-derp-route-bypass` oneshot service.
- Reusable rule: when a host owns both self-hosted DERP and site-specific ingress/egress values, define those values once in the host module and feed them into shared profiles; keep packet-routing safety fixes in the shared profile that owns the affected service.
- Promotion: adopted (generalizable and high-risk if forgotten).
