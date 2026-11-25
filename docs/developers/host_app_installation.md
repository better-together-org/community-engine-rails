# Installing Community Engine in a Rails app

How to add the `better_together` engine to a **new** Rails 8.1 app or to an **existing** Rails app. This is the host app install guide; the [README](../../README.md) explains what the engine is and whether it fits your project.

Related guides: [host app migrations from the gem](host_app_migrations_from_gem.md), [production deployment with Dokku](../production/deployment-dokku.md), [host setup script](../production/host_setup_script.md), [platform themes in host apps](systems/platform_themes_host_apps.md), [0.11.0 host upgrade guide](../releases/0.11.0_host_upgrade_guide.md) (upgrading an existing host).

## Requirements

- Ruby 3.4 (the tested version; see `.ruby-version`) and Rails `>= 7.2, < 8.2`. Rails 8.1 is the primary test lane.
- PostgreSQL with PostGIS, and Redis (background jobs and rate limiting).
- Sprockets for assets. The engine brings it in; do not use Propshaft in the host app.

## New app

Start a fresh Rails 8.1 app without the default asset pipeline. Rails 8.1 has no `--asset-pipeline=sprockets` option (it is silently ignored and you get propshaft plus dartsass, whose `application.css` clashes with sprockets), and this engine requires sprockets, which it brings in itself:

```bash
rails new my_app -d postgresql -A -T --skip-kamal --skip-solid --skip-jbuilder
```

The engine needs PostgreSQL with PostGIS, so the database adapter must be `postgis`. The installer switches it for you; if you prefer to do it by hand (or your `database.yml` is customised), set it before running `db:create`:

```yaml
# config/database.yml
default: &default
  adapter: postgis
```

Add this gem and the forks it needs to your Gemfile. Use `branch: 'main'` only to try it out; pin `ref:` to a reviewed commit for anything you deploy (the installer output depends on the gem version, so use a commit that contains the installer):

```ruby
gem 'better_together', '~> 0.11.0',
    github: 'better-together-org/community-engine-rails',
    branch: 'main'
gem 'pundit-resources', git: 'https://github.com/better-together-org/pundit-resources.git', branch: 'master'
gem 'storext', github: 'better-together-org/storext'
# only if you want the rspec and factory_bot generator defaults (rails new -T leaves them out)
gem 'rspec-rails', group: %i[development test]
gem 'factory_bot_rails', group: %i[development test]
```

Sprockets refuses to boot without a manifest, and the installer is itself a Rails command that boots the app, so create an empty one first:

```bash
bundle install
mkdir -p app/assets/config && touch app/assets/config/manifest.js
```

Run the engine installer. It writes the initializer, mounts the engine in `config/routes.rb`, adds the `s3_compatible` storage service, a `config.hosts` initializer, a head-tag provider stub, uuid/rspec/factory_bot generator defaults, an environment-variable fallback for the Active Record encryption keys (see [Credentials and encryption](#credentials-and-encryption)), the `adapter: postgis` switch in `config/database.yml`, the `app/assets/config/manifest.js` links, a theme stub and `bin/check-engine-migrations`:

```bash
rails g better_together:install            # engine migrations run from the gem (default)
rails g better_together:install --migrations=install   # copy migrations into db/migrate instead
```

If you use Action Text, run `rails action_text:install` before the engine migrations and delete its copied migration; CE ships its own Action Text tables.

Set up credentials and encryption keys as described in [Credentials and encryption](#credentials-and-encryption) before you migrate. Seeding enqueues background jobs, so Redis must be reachable (`REDIS_URL`). Create and migrate the database, then seed to create the setup wizard. In the default gem mode nothing is copied; see `docs/developers/host_app_migrations_from_gem.md`.

```bash
rails db:create db:migrate db:seed
```

Open `/<locale>/w/setup_wizard` (for example `/en/w/setup_wizard`) to create the host platform and the first admin. Until the wizard is done every other page redirects there.

## Existing app

The installer is safe to run on an app that already has its own `config/application.rb`, routes and storage setup: every step is idempotent and skips what is already configured. Skip individual steps with `--skip-routes`, `--skip-storage`, `--skip-assets`, `--skip-generators`, `--skip-encryption`, `--skip-database` or `--skip-ci-check`.

1. Add the gem and the forks it needs to the Gemfile (see the New app section) and run `bundle install`.
2. Make sure the app uses sprockets (remove `propshaft` if present) and has `app/assets/config/manifest.js`.
3. Switch the database adapter to `postgis`, and use UUID primary keys for the engine tables (`config.generators { |g| g.orm :active_record, primary_key_type: :uuid }`). The installer does both unless skipped.
4. Run `rails g better_together:install`, then set up credentials and encryption (below).
5. Choose how engine migrations are applied. The default runs them from the gem with no copy step. Apps that already copy engine migrations into `db/migrate` keep working; see [host app migrations from the gem](host_app_migrations_from_gem.md) before switching modes, and never mix the two.
6. Take a database backup and rehearse on a copy of production before migrating an app with existing data.

## Rails dependencies

In addition to other dependencies, the Better Together Community Engine relies on Action Text and Action Storage, which are part of the Rails framework. These dependencies are essential for handling rich text content and file storage within the platform.

### Action Text
[Action Text](https://guides.rubyonrails.org/action_text_overview.html#installation) brings rich text content and editing to Rails. It includes a WYSIWYG editor for writing rich text content stored in a manner compatible with Rails applications.

To set up Action Text, run the following commands:

```bash
rails action_text:install
rails action_text:install:migrations
```

Ensure that you follow the guide linked above to fully configure Action Text in your host app, including adding the required css and JavaScript files for the Trix editor and Action Text.

### Active Storage
[Active Storage](https://guides.rubyonrails.org/active_storage_overview.html#setup) facilitates uploading files to a cloud storage service like Amazon S3, Google Cloud Storage, or Microsoft Azure Storage, and attaching those files to Active Record objects.

To set up Active Storage, run the following command:

```bash
rails app:active_storage:install
```

Ensure that you follow the guide linked above to fully configure Active Storage in your host app, including creating and configuring your `storage.yml` file and setting storage defaults for your environments.

### UUID Primary Keys

The community engine uses UUIDs as primary keys with all tables using `id` as their UUID primary key. To ensure that the Active Storage and Action Text migrations use uuid as the foreign keys for records, set the following configuration in your host app's `application.rb` file or an initializer.

```ruby
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

### Credentials and encryption

Host apps should keep secrets in environment-specific encrypted credentials, decrypted with the Rails master key, rather than in plain environment variables or committed files. Read the official guides first:

- [Securing Rails Applications: Custom credentials](https://guides.rubyonrails.org/security.html#custom-credentials) for how credentials work.
- [Active Record Encryption](https://guides.rubyonrails.org/active_record_encryption.html) for encrypted attributes.

Credentials, per environment:

```bash
bin/rails credentials:edit --environment production   # creates config/credentials/production.yml.enc and production.key
bin/rails credentials:edit --environment staging
```

Commit each `config/credentials/<environment>.yml.enc`. Never commit the matching `config/credentials/<environment>.key`; give it to the running app as `RAILS_MASTER_KEY` (or keep the file on the server) and keep a copy in your password manager. Credentials hold the S3 keys, OAuth client secrets and similar values; read them with `Rails.application.credentials.dig(...)`.

Encrypted attributes: the engine encrypts some columns (for example calendar subscription tokens) with Active Record Encryption, which needs a primary key, a deterministic key and a key derivation salt. Generate them with `bin/rails db:encryption:init` and put the output in each environment's credentials under `active_record_encryption:`. Rails reads them from there automatically, so no initializer code is needed. Use different keys per environment, and never change or lose a key that has already encrypted data: the data cannot be read without it (see the key rotation section of the encryption guide).

The installer also writes an optional fallback that reads `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` and `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` from the environment when they are set. It is for hosts that cannot use credentials; skip it with `--skip-encryption` if you use credentials. Setting only some of the three raises at boot.

