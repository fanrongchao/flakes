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

### L-20260406-006
- Context: local Mihomo/Clash Verge operations need to be repeatable from macOS today and from a future Windows Codex environment that will not have Nix or shell-wrapper parity.
- Decision: keep refresh/runtime control in `mihomocli` itself, and treat platform differences as path/proxy/controller detection concerns rather than shell-script concerns.
- Evidence: `mihomo-cli refresh-clash-verge`, `doctor`, and `runtime` now cover the daily desktop operations directly; Windows preparation only required adding native config/cache roots, Clash Verge `%APPDATA%` path probing, and WinINET proxy detection instead of creating new scripts.
- Reusable rule: when a desktop Mihomo workflow must span macOS and Windows, put the operational logic in the CLI binary and limit platform-specific work to directory discovery, system-proxy introspection, and controller transport differences.
- Promotion: candidate (first cross-platform preparation in this repo).

## 2026-04-07

### L-20260407-001
- Context: `ai-server` needs a browser-friendly Mihomo status UI that stays tailnet-only, does not expose the raw controller secret in dashboard URLs, and should not rely on third-party hosted dashboards talking cross-origin to a local HTTP controller.
- Decision: self-host the dashboard static assets on `ai-server`, publish them behind a dedicated tailnet-only `443` vhost, reverse-proxy `/api` to the localhost Mihomo controller, and bind the controller itself to `127.0.0.1`.
- Evidence: `services.mihomoEgress.externalControllerBindAddress = "127.0.0.1"` now evaluates and deploys on `ai-server`; `curl --resolve mihomo.zhsjf.cn:443:100.64.0.3 https://mihomo.zhsjf.cn/api/version` returned `{"meta":true,"version":"1.19.19"}`; `curl --resolve mihomo.zhsjf.cn:443:100.64.0.3 https://mihomo.zhsjf.cn/zashboard/` returned `200`; the same hostname forced to the public IP `218.11.1.14:443` failed with `SSL_ERROR_SYSCALL`.
- Reusable rule: for tailnet-only Mihomo dashboards, serve static dashboard assets from the managed host itself and front the controller with a same-origin `/api` proxy over the tailnet TLS vhost; do not expose the raw controller listener beyond localhost.
- Promotion: candidate (first confirmation in this repo).

### L-20260407-002
- Context: self-hosted Mihomo dashboards still showed stale setup forms or old controller URLs even after moving to a same-origin `/api` proxy, because browser state persisted from earlier attempts.
- Decision: patch the packaged dashboard assets so each frontend seeds its own same-origin controller state on load, and disable stale service workers that could keep serving old dashboard code.
- Evidence: `metacubexd` was still presenting `http://127.0.0.1/api` from old browser state until the package injected `localStorage` defaults for `endpointList`/`selectedEndpoint`; `yacd` persisted old controller settings in `localStorage["yacd.metacubex.one"]` until the package reset `clashAPIConfigs`; after deploying the patched package, `curl --resolve mihomo.zhsjf.cn:443:100.64.0.3 https://mihomo.zhsjf.cn/metacubexd/` and `/yacd/` both showed injected same-origin `/api` bootstrap code, and `registerSW.js` now unregisters stale service workers.
- Reusable rule: when self-hosting third-party Mihomo dashboards behind a same-origin reverse proxy, patch the packaged frontend to preseed the local controller state and aggressively unregister old service workers so browser caches cannot override the managed backend URL.
- Promotion: candidate (first confirmation in this repo).

### L-20260407-003
- Context: `ai-server` also hosts ordinary HTTPS applications such as AIRS, and some of those should be reachable only through Tailscale without exposing the hostname on the public ingress path.
- Decision: treat tailnet-only app domains the same way as the Mihomo dashboard ingress: bind the app's Caddy vhost to the tailnet IP, add the hostname to `services.ingressHaproxySni.tailnetTlsServerNames`, and keep the public passthrough frontend rejecting that SNI.
- Evidence: `services.aiRelayServices.bindAddress = site.tailnetIPv4` and `site.aiRelayHost` were added to the tailnet-only SNI list on `ai-server`; after deployment, forcing `airs.zhsjf.cn` to `100.64.0.3:443` succeeds while forcing it to `218.11.1.14:443` fails.
- Reusable rule: for tailnet-only HTTPS apps on `ai-server`, bind the Caddy vhost to the tailnet address and register the hostname in the tailnet SNI allow-list so HAProxy rejects the same hostname on the public ingress listener.
- Promotion: candidate (first confirmation in this repo).

### L-20260407-004
- Context: `zhsjf.cn` uses a wildcard public `A` record, so removing an app service does not automatically stop its hostname from resolving on the Internet.
- Decision: when retiring a single subdomain under that wildcard, add or update an explicit record for the hostname instead of assuming the wildcard will disappear; use a tailnet IP for still-supported tailnet-only services and a sink address for retired names that should stop working.
- Evidence: AliDNS showed `* -> 218.11.1.14` while `airs` and `aiapi` had no explicit records of their own; that wildcard was enough to keep both names resolving publicly until explicit per-host records were added.
- Reusable rule: if a zone keeps a wildcard public `A` record, retire or privatize child hostnames by overriding them explicitly in DNS; otherwise the wildcard will continue to publish the old public endpoint.
- Promotion: candidate (first confirmation in this repo).

### L-20260407-005
- Context: infra changes on `ai-server` are easier to reason about when the host's `~/flakes` checkout exactly matches Git history, instead of accumulating local edits, ad-hoc hotfixes, or forgotten stashes.
- Decision: treat the remote `~/flakes` checkout as a read-only deployment mirror: make changes locally, commit and push them, then update the host with `git fetch` + `git merge --ff-only` before `nixos-rebuild`.
- Evidence: once `ai-server` stayed on clean fast-forwarded commits only, rollout verification became predictable: local `HEAD`, remote `HEAD`, deployed generation, and rollback target all lined up without having to remember host-only patches.
- Reusable rule: keep managed host repos permanently clean; never rely on remote dirty worktrees for durable infra changes, and prefer fast-forward-only updates from the canonical local repo.
- Promotion: candidate (first confirmation in this repo).

### L-20260408-001
- Context: the AIRS stack on `ai-server` was up, but admin login kept failing because Redis could not persist snapshots on its bind-mounted `/data` volume, which in turn prevented AIRS from refreshing the live admin credentials from `runtime.env`.
- Decision: in the AIRS prepare phase, create the Redis data directory with the container's runtime ownership (`uid 999`, `gid 1000`) before starting the stack, instead of leaving the bind mount as `root:root`.
- Evidence: before the fix, Redis logged `Failed opening the temp RDB file ... Permission denied` and AIRS logged `Failed to reload admin credentials`; after chowning `/var/lib/ai-relay-services/redis` to `999:1000` via the NixOS prepare service, Redis snapshotting recovered and AIRS returned `{"success":true}` for `POST /web/auth/login`.
- Reusable rule: for bind-mounted container state directories, match the host-side ownership to the service user inside the container when the image drops privileges internally; a root-owned mount can still break persistence even if the container entrypoint itself starts as root.
- Promotion: candidate (first confirmation in this repo).

### L-20260408-002
- Context: the AIRS compose stack was still using `docker.io/weishaw/claude-relay-service:latest`, which made upgrades implicit and reduced rollback confidence because the running image could drift independently of Git history.
- Decision: pin AIRS to the explicit upstream release image `v1.1.298` with its digest, and pull that exact image during service start instead of relying on whatever `latest` happens to resolve to.
- Evidence: the upstream release for `v1.1.298` published matching Docker Hub and GHCR images, and switching the profile to `docker.io/weishaw/claude-relay-service:v1.1.298@sha256:a030479017c12c5a951a0e112b110b0fda1c3ef2a7ba9ffbcded1d364c88e904` kept the existing bind-mounted state while making the deployed image auditable and reproducible.
- Reusable rule: for third-party application containers managed by flakes, prefer release tag + digest pins over `latest`, and make the systemd-managed start path pull the exact pinned image so deploys fail fast when the requested artifact is unavailable.
- Promotion: candidate (first confirmation in this repo).
