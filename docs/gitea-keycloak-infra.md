# Gitea + Keycloak Infrastructure

> This document records the current private Git service infrastructure.
> The executable source of truth remains the Nix flake modules and SOPS secrets.

## Current Service

- Service: Gitea
- Hostname: `code.xfa.cn`
- Access model: tailnet-only
- DNS: `code.xfa.cn A 100.64.0.33`
- Service node: `infra-zero`
- Service node LAN IP: `192.168.3.88`
- Service node Tailnet IP: `100.64.0.33`
- Identity provider: Keycloak realm `zhsjf`
- Keycloak hostname: `auth.zhsjf.cn`
- Existing GitLab at `g.xfa.cn` is not replaced by this service.

## Flake Layout

- `hosts/infra-zero/default.nix`
  - Enables `services.companyGitea`
  - Binds Gitea Web and SSH to the `infra-zero` Tailnet IP
  - Keeps system OpenSSH on LAN `192.168.3.88:22`
- `profiles/company-gitea.nix`
  - Defines Gitea settings, Caddy TLS, bootstrap admin, OIDC auth source, dump timer
  - Configures Keycloak OIDC group gating and group-to-team mapping
- `hosts/ai-server/default.nix`
  - Runs Keycloak and Headscale
  - Keeps `code.xfa.cn` out of old `ai-server` ingress
  - Configures Mihomo fake-IP bypass for `code.xfa.cn`
- `profiles/company-identity-keycloak.nix`
  - Defines/reconciles Keycloak realm groups and the `gitea` OIDC client
- `secrets/identity.yaml`
  - Holds `gitea/admin_password`
  - Holds `gitea/oidc_client_secret`
- `secrets/aliyun.yaml`
  - Holds AliDNS credentials used by Caddy DNS-01 TLS on `infra-zero`

## Network Path

Web:

```text
Tailnet client -> code.xfa.cn / 100.64.0.33:443 -> Caddy on infra-zero -> Gitea 127.0.0.1:3000
```

Git SSH:

```text
Tailnet client -> git@code.xfa.cn:owner/repo.git -> 100.64.0.33:22 -> Gitea built-in SSH
```

Management SSH:

```text
operator -> xfa@192.168.3.88:22 -> infra-zero system OpenSSH
```

Do not put Gitea Web or SSH back through `ai-server` HAProxy unless explicitly rolling back to the old gateway model.

## Gitea Runtime Settings

Important Gitea settings managed by `profiles/company-gitea.nix`:

- `ROOT_URL = https://code.xfa.cn/`
- `DOMAIN = code.xfa.cn`
- `HTTP_ADDR = 127.0.0.1`
- `HTTP_PORT = 3000`
- `START_SSH_SERVER = true`
- `BUILTIN_SSH_SERVER_USER = git`
- `SSH_DOMAIN = code.xfa.cn`
- `SSH_USER = git`
- `SSH_PORT = 22`
- `SSH_LISTEN_HOST = 100.64.0.33`
- `SSH_LISTEN_PORT = 22`
- `DISABLE_HTTP_GIT = true`
- `ENABLE_BASIC_AUTHENTICATION = false`
- `ALLOW_ONLY_EXTERNAL_REGISTRATION = true`
- `ENABLE_AUTO_REGISTRATION = true`

Code access is SSH-key-only. HTTPS Git clone/push/pull is intentionally disabled.

## Identity And Access

Login is controlled by Keycloak group claims.

- Required login group: `gitea_users`
- OIDC client id: `gitea`
- OIDC discovery URL: `https://auth.zhsjf.cn/realms/zhsjf/.well-known/openid-configuration`
- OIDC scopes: `profile`, `email`, `groups`
- Required claim: `groups` contains `gitea_users`

Local Gitea users are created automatically on first Keycloak login.

The local break-glass admin remains:

- Username: `breakglass-admin`
- Password source: `gitea/admin_password` in SOPS

Do not make Keycloak group membership automatically grant site admin unless that is a deliberate future change.

## Keycloak Groups

Current Gitea-related groups:

- `gitea_users`
  - Allows Keycloak login to Gitea
- `gitea_admins`
  - Reserved; not currently mapped to Gitea site admin
- `gitea_altivis_members`
  - Maps to `altivis/Members` in Gitea
- `gitea_low_altitude_members`
  - Maps to `low_altitude_projects/Members` in Gitea

Current membership snapshot:

- `gitea_users`
  - `fanrongchao`
  - `pantianrui`
  - `shanmengjiao`
- `gitea_altivis_members`
  - `pantianrui`
  - `shanmengjiao`
- `gitea_low_altitude_members`
  - `gengweiwei`

If a user is added to `gitea_altivis_members` but has not logged in to Gitea yet, they will not appear in Gitea org membership until their first successful Keycloak login creates the local Gitea account.

## Gitea Organizations And Teams

Current organization:

- `altivis`
- `low_altitude_projects`

Current team:

- `altivis/Members`
  - Includes all repositories
  - Can create organization repositories
  - Has write access to:
    - `repo.code`
    - `repo.issues`
    - `repo.pulls`
    - `repo.releases`
    - `repo.wiki`
    - `repo.projects`
- `low_altitude_projects/Members`
  - Includes all repositories
  - Can create organization repositories
  - Has write access to:
    - `repo.code`
    - `repo.issues`
    - `repo.pulls`
    - `repo.releases`
    - `repo.wiki`
    - `repo.projects`

OIDC group-to-team mapping:

```json
{
  "gitea_altivis_members": {
    "altivis": ["Members"]
  },
  "gitea_low_altitude_members": {
    "low_altitude_projects": ["Members"]
  }
}
```

This mapping is reconciled by `gitea-bootstrap.service`.

## User Operations

Add a user to Gitea and `altivis/Members`:

1. Ensure the Keycloak user exists in realm `zhsjf`.
2. Add the user to `gitea_users`.
3. Add the user to `gitea_altivis_members`.
4. Ask the user to log in once at `https://code.xfa.cn`.
5. Verify Gitea org membership.

Example Keycloak group verification from `ai-server`:

```bash
base=http://127.0.0.1:8081
admin_pass=$(sudo cat /run/secrets/keycloak/bootstrap_admin_password | tr -d '\n')
token=$(
  curl -fsS "$base/realms/master/protocol/openid-connect/token" \
    -d grant_type=password \
    -d client_id=admin-cli \
    --data-urlencode username=admin \
    --data-urlencode "password=$admin_pass" \
  | jq -r .access_token
)

curl -fsS -H "Authorization: Bearer $token" \
  "$base/admin/realms/zhsjf/groups?search=gitea_users"
```

For repeatable changes, prefer adding declarative/reconcile logic to:

- `profiles/company-identity-keycloak.nix` for Keycloak groups and clients
- `profiles/company-gitea.nix` for Gitea OIDC mappings

## Operator CLI

Local `tea` CLI is installed by Home Manager on the Mac:

- Package: `tea`
- Current pinned overlay version: `0.14.1`
- Config path on macOS: `~/Library/Application Support/tea/config.yml`
- Login name: `xfa`
- Server URL: `https://code.xfa.cn`

Useful commands:

```bash
tea whoami
tea admin users list
tea org list
tea api orgs/altivis/members | jq -r '.[] | .login'
tea api orgs/altivis/teams | jq -r '.[] | [.id,.name] | @tsv'
tea repo list
tea repo create --owner altivis --name example --private --init
```

`tea` does not expose every Gitea admin function as a first-class command. Use `tea api` for organization teams, team members, and other REST API operations.

## Deployment

Deploy `infra-zero` Gitea changes:

```bash
ssh ai-server 'ssh xfa@192.168.3.88 "cd ~/flakes && git fetch origin master && git merge --ff-only origin/master && sudo nixos-rebuild switch --flake ~/flakes#infra-zero"'
```

Deploy `ai-server` Keycloak changes:

```bash
ssh ai-server 'cd ~/flakes && git fetch origin master && git merge --ff-only origin/master && sudo nixos-rebuild switch --flake ~/flakes#ai-server'
```

If `ai-server` GitHub SSH fetch is intercepted by Mihomo fake IP, use an HTTPS override:

```bash
ssh ai-server 'cd ~/flakes && git -c url.https://github.com/.insteadOf=git@github.com: fetch origin master && git merge --ff-only origin/master && sudo nixos-rebuild switch --flake ~/flakes#ai-server'
```

## Verification

DNS:

```bash
dig +short code.xfa.cn A
```

Expected:

```text
100.64.0.33
```

Web:

```bash
curl -kfsSI https://code.xfa.cn/ | sed -n '1,8p'
```

Expected:

```text
HTTP/2 200
```

OIDC:

```bash
curl -kfsSIL https://code.xfa.cn/user/oauth2/Keycloak | sed -n '1,26p'
```

Expected first hop:

```text
HTTP/2 307
location: https://auth.zhsjf.cn/realms/zhsjf/protocol/openid-connect/auth...
```

HTTP Git disabled:

```bash
curl -kfsSI "https://code.xfa.cn/fanrongchao/example.git/info/refs?service=git-upload-pack"
```

Expected: not `200`; current smoke tests observed `403`.

SSH Git:

```bash
git clone git@code.xfa.cn:owner/repo.git
```

Service health:

```bash
ssh ai-server 'systemctl --no-pager --failed; systemctl is-active keycloak caddy haproxy mihomo'
ssh ai-server 'ssh xfa@192.168.3.88 "systemctl --no-pager --failed; systemctl is-active gitea caddy tailscaled postgresql"'
```

Listeners on `infra-zero`:

```bash
ssh ai-server 'ssh xfa@192.168.3.88 "ss -ltn | grep -E \"100\\.64\\.0\\.33:(22|443)|127\\.0\\.0\\.1:3000|192\\.168\\.3\\.88:22\""'
```

Expected listeners:

- `100.64.0.33:443` Caddy
- `100.64.0.33:22` Gitea built-in SSH
- `127.0.0.1:3000` Gitea HTTP
- `192.168.3.88:22` system OpenSSH

## Backups

Gitea dump is enabled:

- Unit: `gitea-dump.service`
- Timer: `gitea-dump.timer`
- Path: `/var/lib/gitea/dump`
- Type: zip
- Schedule: daily around `04:31`

Manual dump:

```bash
ssh ai-server 'ssh xfa@192.168.3.88 "sudo systemctl start gitea-dump.service && sudo ls -lah /var/lib/gitea/dump | tail"'
```

Before putting critical repositories on this service, perform and document a restore rehearsal.

## Rollback

Rollback `infra-zero`:

```bash
ssh ai-server 'ssh xfa@192.168.3.88 "sudo nixos-rebuild switch --rollback"'
```

Rollback `ai-server`:

```bash
ssh ai-server 'sudo nixos-rebuild switch --rollback'
```

DNS rollback should normally not be needed unless reverting to the old gateway ingress model. If that model is intentionally restored, point `code.xfa.cn` back to the `ai-server` Tailnet IP `100.64.0.3` and restore the old HAProxy/Caddy Gitea ingress config.

## Known Edges

- New Keycloak users do not appear in Gitea until first login.
- Gitea team sync runs during OIDC login, based on the latest Keycloak `groups` claim.
- `tea` is useful for day-to-day operations, but not a complete replacement for all Gitea admin UI/API features.
- Gitea service binding to Tailnet `:22` requires `CAP_NET_BIND_SERVICE` and `PrivateUsers = false` in systemd because the service runs unprivileged.
- `ai-server` Mihomo fake-IP can affect local GitHub SSH fetches; use HTTPS fetch override if needed during deployment.
