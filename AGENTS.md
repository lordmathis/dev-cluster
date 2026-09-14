# Agent Instructions for dev-cluster

GitOps-managed Kubernetes cluster on Hetzner Cloud, deployed with Flux CD.

## Critical Constraints

- **This repository is PUBLIC.** Never expose S3 endpoints, bucket names, or infrastructure details. Use Flux variable substitution (`${VAR}` from `clusters/prod/cluster-vars.yaml`) or SOPS-encrypted secrets instead. The user considers S3 endpoint/bucket exposure a DDoS vector.
- Secrets: only commit `.enc.yaml` files (`sops -e secret.yaml > secret.enc.yaml`), never plain secrets.
- Never run commands that assume a local Kubernetes cluster — the user develops remotely.
- Changes only take effect when committed to Git (Flux reconciles from the repo).

## Conventions

- Traefik ingress uses `IngressRoute` CRDs. Cross-namespace middleware reference format: `<namespace>-<middleware-name>@kubernetescrd` (e.g. `auth-authelia@kubernetescrd`).
- Backup strategy is disaster-recovery focused, not long-term archival (retention: keepLast 3, keepDaily 7).

## Rules

- Do NOT create README or documentation files unless explicitly requested.
- Keep solutions simple and focused on the immediate requirement. No over-engineering, no "nice-to-have" features, no error handling for scenarios that can't happen.
- Read existing files first and follow their patterns exactly, matching YAML formatting and structure.
- Ask before making destructive or irreversible changes.

## User Preferences

- Concise communication, minimal explanations
- No emojis unless explicitly requested
- Direct implementation over discussion
- Simple solutions over complex ones
