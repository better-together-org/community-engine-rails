# Module 08 — Deployments & Day‑2 Ops (Dokku)

Deploy with confidence and operate the platform: secrets, services, monitoring, backups, and incident response.

## Objectives
- Prepare and deploy to Dokku (or similar PaaS)
- Configure secrets/env, DB/PostGIS, Redis, Elasticsearch, Sidekiq, Action Cable
- Operate day‑2: monitoring/logs, migrations, rollbacks, backups/restores

## Deploy Concepts
- Build & release: container build or buildpacks; release health checks
- App config: `DOKKU_CONFIG`/env; secrets for DB/Redis/ES/SMTP
- Services: provision Postgres+PostGIS, Redis, and Elasticsearch plugins/services
- Networking: SSL/TLS, WebSockets (Action Cable), ports, proxy timeouts

## Day‑2 Ops
- Monitoring: Sidekiq Web UI (`/sidekiq`), app logs, error trackers (if configured)
- Migrations: run with release tasks; schema backup before risky changes
- Backups: schedule DB backups; ES snapshots (or export) as needed
- Rollbacks: use platform release history; maintain a runbook

## Reading List
- `docs/production/*` (Dokku deployment, external services configuration)
- `AGENTS.md` → Docker environment usage, security requirements
- Notifiers/jobs docs for background processing expectations

## Hands‑On Lab
- Lab 07 — Dokku Deploy + Rollback Runbook — `./labs/lab_07_dokku_deploy_and_rollback.md`

