# AGENTS.md (clusters/lab/core)

## Scope
- Kubernetes resources and platform manifests for `lab/core`.

## Rules
- Keep boundary clear:
  - NixOS infra lifecycle in `hosts/profiles`.
  - Cluster resources lifecycle in `clusters/lab/core`.
- Secrets must stay in sops-managed files (`*.sops.yaml`).
- Do not commit plaintext Kubernetes Secret manifests.

## Verification
- Validate manifest structure and kustomization references.
- For platform changes, include rollout order and rollback order.

