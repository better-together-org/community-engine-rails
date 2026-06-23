# Lab 07 — Dokku Deploy + Rollback Runbook

Draft and execute a lightweight runbook for deploying and rolling back a release on Dokku.

## Objectives
- Configure app env and services
- Deploy a tagged release and verify health
- Perform a rollback using release history

## Prerequisites
- Dokku server with Postgres+PostGIS, Redis, and Elasticsearch services available
- App created on Dokku and DNS/SSL configured

## Runbook (Template)
1. Prepare
   - Set env: `dokku config:set APP_NAME RAILS_ENV=production RACK_ENV=production` and secrets (DB URL, REDIS URL, ES URL, SMTP)
   - Link services: `dokku postgres:link`, `dokku redis:link`, `dokku elasticsearch:link`
2. Deploy
   - Push: `git push dokku main:master` or `git push dokku <tag>:master`
   - Verify logs: `dokku logs APP_NAME -t`
   - Check `/health` (if available) and homepage
   - Verify `/sidekiq` as a platform manager
3. Migrate
   - Run migration task: `dokku run APP_NAME bin/rails db:migrate`
   - Confirm schema version
4. Rollback
   - List releases: `dokku releases:list APP_NAME`
   - Rollback: `dokku releases:deploy APP_NAME <REVISION>`
   - Verify app health and logs post‑rollback
5. Post‑deploy
   - Watch Sidekiq queues and error rates for 15–30 minutes
   - Update runbook with any deviations

## Notes
- Ensure Action Cable/WebSocket proxy settings and timeouts are configured
- For ES snapshots, consult your ES plugin/cluster docs
- Keep secrets out of VCS; use `dokku config:set` or a secrets manager

