# Multi-Tenancy Upgrade Guide

**Branch:** `feat/multi-tenant`
**Last updated:** 2026-03-21
**Risk level:** Medium — schema changes + data backfills; reversible at each step except the final activation.

---

## Overview

This branch adds a multi-tenant platform architecture, federation MVP, and BCrypt-digested OAuth secrets. Deploying it to an existing CE instance requires the migration sequence below. All steps must be executed in order.

**What changes at the database level:**

| Table | Change |
|-------|--------|
| `better_together_platforms` | New table (18 migrations add columns, indexes, federation tables) |
| `better_together_posts`, `better_together_pages`, `better_together_events` | `platform_id` added (nullable) + federation provenance columns |
| `noticed_notifications` | `platform_id` added |
| `better_together_person_platform_memberships` | New table — people ↔ platform role assignments |
| `better_together_platform_connections` | New table — federation peer links |
| `better_together_federation_access_tokens` | New table — scoped OAuth tokens |

---

## Pre-Deploy Checklist

- [ ] Database backup taken and restore tested
- [ ] Maintenance window scheduled (estimated: 10–30 min depending on data volume)
- [ ] `PLATFORM_URL` env var confirmed to match the public base URL of this deployment
- [ ] `PLATFORM_NAME` and `PLATFORM_TIME_ZONE` env vars set (used by seed run)
- [ ] Redis available (required for `Current.platform` cache)
- [ ] Elasticsearch healthy (`/host/search` sanity check)
- [ ] Sidekiq workers **stopped** before migration, restarted after

---

## Step 1 — Deploy code, run migrations

```bash
# On the server (Dokku or direct Rails)
git pull origin feat/multi-tenant
bundle install
RAILS_ENV=production bundle exec rails db:migrate
```

The migration sequence includes these new backfill steps (run automatically as part of `db:migrate`):

| Migration | Purpose |
|-----------|---------|
| `20260321000001_backfill_content_platform_id` | Assigns `platform_id = host_platform.id` to all existing posts, pages, events where `platform_id IS NULL` |
| `20260321000002_backfill_host_platform_memberships` | Creates active `PersonPlatformMembership` rows for all existing people on the host platform with `platform_manager` (or `platform_steward`) role |

### Verification queries

Run after `db:migrate` succeeds:

```sql
-- Confirm host platform exists
SELECT id, host, url, name FROM better_together_platforms WHERE host = TRUE;

-- Confirm no content records remain unassigned
SELECT COUNT(*) AS unassigned_posts FROM better_together_posts WHERE platform_id IS NULL;
SELECT COUNT(*) AS unassigned_pages FROM better_together_pages WHERE platform_id IS NULL;
SELECT COUNT(*) AS unassigned_events FROM better_together_events WHERE platform_id IS NULL;

-- Confirm people have platform memberships
SELECT COUNT(*) AS people_without_membership
FROM   better_together_people p
WHERE  NOT EXISTS (
  SELECT 1 FROM better_together_person_platform_memberships m
  WHERE  m.member_id = p.id
);
```

All three content counts and `people_without_membership` should be **0** after the migrations.

---

## Step 2 — Seed the host platform (if not already seeded)

```bash
RAILS_ENV=production bundle exec rails db:seed
```

The seed is idempotent — it uses `find_or_create_by!(host: true)`. If the host platform record was created by the migration sequence, this is a no-op.

---

## Step 3 — Restart application

```bash
# Dokku
dokku ps:restart <app-name>

# Direct
bundle exec puma -C config/puma.rb
```

---

## Step 4 — Smoke tests

- [ ] `GET /` — loads without 500 error
- [ ] Log in as an existing admin user — landing page loads
- [ ] `GET /api/v1/platforms` — returns the host platform record
- [ ] `POST /federation/oauth/token` — returns 401 for invalid credentials (confirms federation route is mounted)
- [ ] Create a new post and confirm it shows in the platform feed

---

## Step 5 — RBAC identifier rename (deferred — not in this deployment)

The `rbac_identifier_migration_plan.md` documents a staged rename:
- `platform_manager` → `platform_steward`
- `community_facilitator` + `community_coordinator` → `community_organizer`

**This rename is NOT included in this deployment.** The `access_control_builder` defines both `platform_steward` and `platform_manager` for compatibility. The rename requires:
1. A separate data migration updating live role identifiers in memberships and invitations
2. A code sweep removing `platform_manager` fallback references
3. Coordinated seed re-run

Schedule this as a follow-up release with its own checklist.

---

## Rollback Procedure

If the migration fails or a critical error is detected post-deploy:

```bash
# Roll back the two backfill migrations (they raise IrreversibleMigration)
# — these cannot be automatically reversed.
# Restore from the pre-deploy backup instead:
RAILS_ENV=production bundle exec rails db:rollback STEP=N
# where N = number of new migrations; review `db:migrate:status` to confirm

# Restore backup if needed
pg_restore -d <database> <backup_file>
```

The backfill migrations (`20260321000001`, `20260321000002`) raise `ActiveRecord::IrreversibleMigration` on rollback. If you need to roll back past them, restore from the pre-deploy backup.

---

## Known Limitations (greenfield only)

The following features require a federation peer to be registered and approved before they function:

- `GET /federation/content_feed` — returns empty set with no approved peers
- Federation OAuth token exchange — requires a configured `PlatformConnection`

These are expected for a fresh deployment with no federation peers.
