
# Dokku Deployment

Before proceeding, review and configure required external services and environment variables:

- See: [External Services Configuration](./external-services-to-configure.md)

# Prepare the host

Run `bin/prod/host-setup.sh` first on a new server (Debian 12/13 or Ubuntu 22.04, 24.04, 26.04). It installs Docker and Dokku at the versions pinned in `bin/prod/host-setup.versions`, hardens ssh, ufw and fail2ban, and can create the app, its Postgres/PostGIS and Redis services, domain and certificate. Always read the plan first:

```bash
sudo bin/prod/host-setup.sh --dry-run --yes --app=myapp --domain=app.example.org --letsencrypt-email=ops@example.org
```

Cloudflared, NordVPN and Elasticsearch are opt-in (`--with-cloudflared`, `--with-nordvpn`, `--with-elasticsearch`). Details: [Host Setup Script](./host_setup_script.md). A host app generated with the Community Engine installer carries its own copy under `bin/prod/`. The manual commands below do the same work step by step.

# Create the app

This app uses dokku to manage its production environment.

```bash
dokku apps:create communityengine
```

# Database

This app uses a PostGIS database. It is an extended version of PostgreSQL with enhanced capacity to work with geospatial data.

Visit the dokku-postgres GitHub repo for installation and usage instructions:

https://github.com/dokku/dokku-postgres

Create the postgres instance with support for postGIS:

```bash
# Use the PostGIS image and version pinned in bin/prod/host-setup.versions
dokku postgres:create communityengine --image imresamu/postgis --image-version 17-3.6.1-bookworm
```

Link your new postgres instance to your applciation:

```bash
dokku postgres:link communityengine communityengine
```

# Redis

This app uses Redis for the background job queue.

Visit the dokku-redis GitHub repo for installation and usage instructions:

https://github.com/dokku/dokku-redis

Create the redis instance (image and version from `bin/prod/host-setup.versions`):

```bash
dokku redis:create communityengine --image redis --image-version 7.4.12-alpine
```

Link your new redis instance to your applciation:

```bash
dokku redis:link communityengine communityengine
```

## Storage

Choose one backend. The host setup script applies the non-secret settings for you (`--storage-backend=garage|aws|local`); set the access key pair yourself, never on a shared command line.

For Garage or another S3-compatible store, set `ACTIVE_STORAGE_SERVICE=s3_compatible`, `ACTIVE_STORAGE_ROUTE=proxy`, `S3_ENDPOINT`, `S3_BUCKET_NAME`, `S3_REGION`, `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` and `AWS_RESPONSE_CHECKSUM_VALIDATION=when_required`. For AWS S3, set `ACTIVE_STORAGE_SERVICE=amazon`.

## Set build variables (AWS S3 only)

These build args are needed only for the AWS backend; Garage and local builds do not use them.

``` bash
dokku docker-options:add communityengine.app build '--build-arg AWS_ACCESS_KEY_ID'
dokku docker-options:add communityengine.app build '--build-arg AWS_SECRET_ACCESS_KEY'
dokku docker-options:add communityengine.app build '--build-arg FOG_DIRECTORY'
dokku docker-options:add communityengine.app build '--build-arg FOG_HOST'
dokku docker-options:add communityengine.app build '--build-arg FOG_REGION'
dokku docker-options:add communityengine.app build '--build-arg ASSET_HOST'
dokku docker-options:add communityengine.app build '--build-arg CDN_DISTRIBUTION_ID'
```

## Logging

Configure the application log level with the `RAILS_LOG_LEVEL` environment variable. Use `info` or `warn` in production and reserve `debug` for troubleshooting.
