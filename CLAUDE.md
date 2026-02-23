# Claude Instructions for dev-cluster

## Project Overview

This is a GitOps-managed Kubernetes cluster running on Hetzner Cloud, managed with Flux CD. The cluster uses a declarative approach where all configuration is stored in Git and automatically applied to the cluster.

## Repository Structure

```
dev-cluster/
├── clusters/prod/          # Flux system configuration and cluster entry point
├── infrastructure/
│   ├── core/              # Core infrastructure (storage, networking)
│   └── controllers/       # Infrastructure controllers (k8up, traefik, cert-manager, etc.)
└── apps/
    ├── base/              # Base app configurations
    └── prod/              # Production overlays with environment-specific values
```

## Key Technologies

- **Flux CD**: GitOps continuous delivery
- **Helm**: Package management
- **Kustomize**: Manifest customization
- **SOPS + Age**: Secrets encryption
- **local-path-provisioner**: Local storage with `retain-local-path` storage class
- **k8up**: Kubernetes backup operator using Restic + S3
- **CloudNativePG**: PostgreSQL operator for managed database clusters

## Important Conventions

### Application/Controller Structure

Each app or controller follows this pattern:
```
app-name/
├── kustomization.yaml      # Required: lists all resources
├── namespace.yaml          # Required: namespace definition
├── repository.yaml         # Helm repository source
├── release.yaml           # HelmRelease definition
└── values.yaml            # Helm value overrides (prod apps only)
```

### Secrets Management

- All secrets are encrypted with SOPS using Age encryption
- Pattern: `secret.yaml` → `sops -e secret.yaml > secret.enc.yaml`
- Only commit `.enc.yaml` files, never plain secrets
- The Age key is stored as a Kubernetes secret in the flux-system namespace

### Variable Substitution

- Use Flux variable substitution for sensitive non-secret values (like S3 endpoints, bucket names)
- Variables are defined in `clusters/prod/cluster-vars.yaml`
- Reference in manifests: `${VARIABLE_NAME}`
- Example: `endpoint: "${BACKUP_S3_ENDPOINT}"`

### Storage

- Default storage class: `retain-local-path`
- PVCs use local-path-provisioner
- For backups: annotate PVCs with `k8up.io/backup: "true"`

### Traefik Ingress & Middleware

- Use `IngressRoute` CRD for Traefik ingress configuration
- When referencing middleware from another namespace, use the format: `<namespace>-<middleware-name>@kubernetescrd`
- Example: To use the `authelia` middleware from the `auth` namespace:
  ```yaml
  middlewares:
    - name: "auth-authelia@kubernetescrd"
  ```
- The Authelia forward-auth middleware is defined in `apps/prod/authelia/forward-auth-middleware.yaml`

## Project-Specific Rules

### Documentation

**CRITICAL**: Do NOT create README files or documentation unless explicitly requested by the user. This includes:
- No README.md files in app/controller directories
- No BACKUP-README.md, SETUP.md, etc.
- No comment-only YAML files for documentation

The user prefers concise, direct implementation without unnecessary documentation files.

### Security & Privacy

**This repository is PUBLIC**. Be extremely careful about:
- Never expose S3 endpoints, bucket names, or infrastructure details in public manifests
- Use Flux variable substitution (`${VAR}`) for potentially sensitive configuration
- Use SOPS-encrypted secrets for all credentials
- The user considers S3 endpoint/bucket exposure a security risk (DDoS vector)

### Code Style

- Keep solutions simple and focused on the immediate requirement
- Avoid over-engineering or adding "nice-to-have" features
- Don't add error handling for scenarios that can't happen
- Follow existing patterns in the codebase exactly
- Match the YAML formatting and structure of existing files

### Backup Strategy

- Disaster recovery focused (not long-term archival)
- Retention: keepLast: 3, keepDaily: 7
- PostgreSQL databases (CloudNativePG) use pod annotations for `pg_dumpall` pre-backup hooks
- Mail backups use custom Restic CronJobs (3 separate jobs per account), daily at 2:30 AM
- Backup pods run as `runAsUser: 0` to read all files

## Common Operations

### Adding a New Application

1. Create base structure in `apps/base/app-name/`
2. Create prod overlay in `apps/prod/app-name/`
3. Add to `apps/prod/kustomization.yaml`
4. If secrets needed, create `secret.yaml`, encrypt with SOPS, commit `.enc.yaml`

### Adding a New Controller

1. Create controller directory in `infrastructure/controllers/controller-name/`
2. Follow the standard structure (namespace, repository, release, kustomization)
3. Add to `infrastructure/controllers/kustomization.yaml`

### Encrypting Secrets

```bash
sops -e secret.yaml > secret.enc.yaml
```

### Variable Substitution

Add variables to `clusters/prod/cluster-vars.yaml`, reference with `${VAR_NAME}` in manifests.

## Deployed Applications

### Production Apps
- **forgejo**: Git service with CloudNativePG PostgreSQL backend (has k8up backups)
- **ghost**: Blog/CMS (SQLite3, ghost:5-alpine)
- **authelia**: Authentication/SSO (HelmRelease v0.10.49, SQLite local storage, file-based users)
- **k9s-web**: Kubernetes dashboard web UI (namespace: k9s)
- **homelab-proxy**: Proxy service
- **lemma**: Custom application (ghcr.io/lordmathis/lemma:latest, SQLite3)
- **lute**: Custom application
- **mail-backup**: Mail synchronization (mbsync, hourly CronJobs) + Restic backups (3 mail accounts, daily)

### Infrastructure Controllers
- **metallb**: Load balancer
- **cert-manager**: TLS certificate management
- **traefik**: Ingress controller (v39.0.2, with crowdsec-bouncer plugin)
- **tailscale**: VPN/networking
- **crowdsec**: Security/IPS
- **k8up**: Backup operator (v4.8.6)
- **cloudnative-pg**: PostgreSQL operator (v0.27.1)

## Backup Configuration

### Forgejo (k8up)

k8up Schedule CRD in `apps/prod/forgejo/backup-schedule.yaml`:
- Daily backups at 2:00 AM
- Weekly checks (Sundays 3:00 AM)
- Weekly pruning (Sundays 4:00 AM)
- S3-compatible backend, credentials and endpoint via Flux variable substitution
- CloudNativePG pod annotation for `pg_dumpall` pre-backup hook

#### CloudNativePG Backup Annotations

```yaml
# On the CloudNativePG Cluster spec (db-cluster.yaml):
inheritedMetadata:
  annotations:
    k8up.io/backup: "true"
    k8up.io/backupcommand: sh -c 'pg_dumpall --clean -U postgres'
    k8up.io/file-extension: .sql
```

### Mail Backup (Restic CronJobs)

3 separate Restic CronJobs in `apps/prod/mail-backup/restic-cronjob.yaml`:
- Daily at 2:30 AM, one per mail account
- keep-daily 7 retention
- Includes `restic unlock --remove-all || true` for stale lock handling

## Working with This Project

When making changes:
1. Always read existing files to understand current patterns
2. Match existing style and structure exactly
3. Test changes don't break Flux reconciliation
4. Remember this is GitOps - changes must be committed to Git to take effect
5. Never run commands that assume a local Kubernetes cluster (user develops remotely)

## User Preferences

- Concise communication, minimal explanations
- No emojis unless explicitly requested
- Direct implementation over discussion
- Simple solutions over complex ones
- Follow existing patterns strictly
- Ask before making destructive or irreversible changes
