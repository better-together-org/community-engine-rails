# Running engine migrations from the gem

Fresh host apps run the Community Engine migrations in place. Nothing is copied into `db/migrate`, so upgrading the gem upgrades the schema with `rails db:migrate`.

## Default: `--migrations=gem`

```bash
rails g better_together:install
rails db:create db:migrate
```

The engine's `better_together.append_migrations` initializer adds the gem's `db/migrate` to the host's migration paths. All migrations are idempotent and run from an empty database (CI job `migrations-from-zero`, locally `bin/ci-migrate-from-zero`).

The installer writes `bin/check-engine-migrations`. Run it in CI: it fails when `db/migrate/*.better_together.rb` exists, which means migrations were copied and will run twice or drift.

## Opt-in: `--migrations=install`

```bash
rails g better_together:install --migrations=install
rails better_together:install:migrations
rails db:migrate
```

Copied migrations carry the `.better_together.rb` suffix. The engine then stops appending its own path, so exactly one copy runs. Choose this only when you must review or pin each migration. The choice is recorded as `BetterTogether.host_migrations_mode` in `config/initializers/better_together.rb`.

## Switching from install to gem

Delete `db/migrate/*.better_together.rb`, then confirm `rails db:migrate:status` shows no `NO FILE` rows for engine versions. Versions stay identical, so history is preserved.

## Switching from gem to install

Do not run `better_together:install:migrations` on an app that already ran the engine migrations in place. The copies get new timestamps, so the database sees 392 pending migrations and the first one fails with `PG::DuplicateTable`. The `.better_together.rb` files also switch the in-place mode off, which is why `bin/check-engine-migrations` fails the build when they appear. Choose the mode before the first `db:migrate`; changing it on a migrated database is not covered here.

## Upgrading the gem

`bundle update better_together` then `rails db:migrate` runs only the new engine migrations and updates `db/schema.rb`; there is no copy step. Review the schema diff in the pull request, and read the new files under the gem's `db/migrate` before upgrading (some are destructive). Host migrations are ordered by timestamp together with the engine's: one dated before an engine migration that is still pending simply runs in version order, and one dated earlier than the newest applied version runs on the next `db:migrate`. Rolling back (`db:rollback`, `db:migrate:redo`) works on engine versions like any other.

## Server setup

Production host provisioning is handled by `bin/prod/host-setup.sh` (see the production setup docs).
