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

## Server setup

Production host provisioning is handled by `bin/prod/host-setup.sh` (see the production setup docs).
