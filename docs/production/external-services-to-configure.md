# External Services & Environment Configuration

This guide lists external services used in production and the environment variables required to configure them. See `.env.prod.sample` for a concise reference of the variables used by this project.

Important notes:
- Prefer setting a single `DATABASE_URL`, `REDIS_URL`, and `ELASTICSEARCH_URL` where supported.
- Hostnames and asset/CDN domains must be consistent (`APP_HOST`, `ASSET_HOST`).
- Keep secrets out of the repo; use your platform’s secret manager (e.g., Dokku `config:set`).

## Amazon S3 / Asset Storage & CDN

Used for precompiled asset uploads and optionally as a CDN origin. The project uses `fog-aws` and `asset_sync` (see `spec/dummy/config/initializers/asset_sync.rb`).

Required variables:
- `AWS_ACCESS_KEY_ID`: AWS access key for the asset bucket.
- `AWS_SECRET_ACCESS_KEY`: AWS secret key.
- `FOG_DIRECTORY`: S3 bucket name (alias: `S3_BUCKET_NAME`).
- `FOG_REGION`: S3 region (alias: `S3_REGION`).

Recommended/optional:
- `FOG_HOST`: Custom host for S3-compatible providers or CDN origin.
- `ASSET_HOST`: Public CDN domain serving compiled assets.
- `CDN_DISTRIBUTION_ID`: If using CloudFront or similar for invalidations.
- `AWS_SESSION_TOKEN`: Temporary credentials session token (if using STS).

Example environment:
```bash
# S3 / CDN
AWS_ACCESS_KEY_ID=... 
AWS_SECRET_ACCESS_KEY=...
FOG_DIRECTORY=your-bucket
FOG_REGION=us-east-1
# Optional for S3-compatible providers/CDN
FOG_HOST=s3.amazonaws.com
ASSET_HOST=cdn.yourdomain.com
CDN_DISTRIBUTION_ID=E123EXAMPLE
```

Rails configuration references:
- `spec/dummy/config/initializers/asset_sync.rb:5` – S3 credentials and bucket settings
- `spec/dummy/config/environments/production.rb:39` – `config.asset_host`

## OpenAI (Optional Features)

Some features (e.g., translations, bots) use OpenAI if available. If unset, those features remain disabled.

Required to enable:
- `OPENAI_ACCESS_TOKEN`: API key used by helpers and robots.

Optional:
- `OPENAI_API_BASE`: Override API base (e.g., Azure OpenAI endpoint).

Example environment:
```bash
OPENAI_ACCESS_TOKEN=sk-...
# Optional for Azure/OpenAI proxy
# OPENAI_API_BASE=https://your-azure-endpoint.openai.azure.com
```

References:
- `app/robots/better_together/application_bot.rb:10`
- `app/helpers/better_together/translatable_fields_helper.rb:20`

## Sentry (Backend + Browser)

Backend error reporting and performance traces:
- `SENTRY_DSN`: Server DSN for the Ruby SDK.
- `GIT_REV`: Git SHA/version for release tagging.
- Optional sampling: `SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_PROFILES_SAMPLE_RATE`.

Browser (frontend) error reporting:
- `SENTRY_CLIENT_KEY`: Public key used by the Sentry browser SDK loaded in layouts.

Example environment:
```bash
SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>
SENTRY_CLIENT_KEY=<public-browser-key>
GIT_REV=$(git rev-parse --short HEAD)
# Optional sampling
# SENTRY_TRACES_SAMPLE_RATE=0.2
# SENTRY_PROFILES_SAMPLE_RATE=0.1
```

References:
- `spec/dummy/config/initializers/sentry.rb:3`
- `app/views/layouts/better_together/application.html.erb:5`
- `app/views/layouts/better_together/turbo_native.html.erb:5`

## Email (SMTP / SendGrid)

Used by Action Mailer for transactional emails. Configure your SMTP provider (SendGrid, Postmark, SES SMTP, etc.).

Required variables:
- `SMTP_ADDRESS`: SMTP server hostname.
- `SMTP_PORT`: SMTP port (587 for STARTTLS or 465 for TLS).
- `SMTP_USERNAME`: SMTP username.
- `SMTP_PASSWORD`: SMTP password.

Example environment:
```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=SG.XXXX...
```

Minimal Action Mailer example (Rails initializer):
```ruby
# config/initializers/mailer.rb
Rails.application.configure do
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_ADDRESS'),
    port: Integer(ENV.fetch('SMTP_PORT', 587)),
    user_name: ENV.fetch('SMTP_USERNAME'),
    password: ENV.fetch('SMTP_PASSWORD'),
    authentication: :plain,
    enable_starttls_auto: true
  }
end
```

## Elasticsearch

Used for search indexing via `elasticsearch-model`.

Preferred:
- `ELASTICSEARCH_URL`: Full URL (e.g., `http://localhost:9200`).

Fallback variables (if `ELASTICSEARCH_URL` is not set):
- `ES_HOST`: Host URL (default `http://localhost`).
- `ES_PORT`: Port (default `9200`).

Example environment:
```bash
ELASTICSEARCH_URL=http://elasticsearch:9200
# or
# ES_HOST=http://elasticsearch
# ES_PORT=9200
```

Reference:
- `config/initializers/elasticsearch.rb:6`

## Redis

Used by Sidekiq (background jobs) and optionally Rack::Attack cache store.

Variables:
- `REDIS_URL`: Redis connection string (e.g., `redis://:password@host:6379/0`).
- `RACK_ATTACK_REDIS_URL`: Optional Redis for Rack::Attack throttling/cache.

Example environment:
```bash
REDIS_URL=redis://redis:6379/0
# Optional dedicated Redis for Rack::Attack
# RACK_ATTACK_REDIS_URL=redis://redis:6379/1
```

Reference:
- `config/initializers/rack_attack.rb:15`

## PostgreSQL (PostGIS)

Database connection is provided via `DATABASE_URL`. PostGIS is required in production.

Variables:
- `DATABASE_URL`: Full Postgres connection string.

Example:
```bash
DATABASE_URL=postgres://user:password@db:5432/community_engine_production
```

## Hostnames & Rails Keys

Hostnames:
- `ALLOWED_HOSTS`: Comma-separated hostnames allowed by Rails.
- `APP_HOST`: Public host used for URL generation.
- `BASE_URL`: Base URL without scheme if used by external scripts.

Rails secrets:
- `SECRET_KEY_BASE`: Rails secret key base (required in production).
- `RAILS_MASTER_KEY`: Key to decrypt credentials if using `config/credentials/*.yml.enc`.

Example:
```bash
ALLOWED_HOSTS=yourdomain.com
APP_HOST=yourdomain.com
BASE_URL=yourdomain.com

SECRET_KEY_BASE=<generated-secret>
# If using Rails encrypted credentials
# RAILS_MASTER_KEY=<your-master-key>
```

## Quick Checklist

- S3/CDN: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `FOG_DIRECTORY`, `FOG_REGION`, `ASSET_HOST`
- OpenAI: `OPENAI_ACCESS_TOKEN` (optional)
- Sentry: `SENTRY_DSN`, `SENTRY_CLIENT_KEY`, `GIT_REV`
- Email: `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- Elasticsearch: `ELASTICSEARCH_URL` or `ES_HOST` + `ES_PORT`
- Redis: `REDIS_URL` (+ `RACK_ATTACK_REDIS_URL` optional)
- PostgreSQL: `DATABASE_URL`
- Host/Secrets: `ALLOWED_HOSTS`, `APP_HOST`, `SECRET_KEY_BASE`
