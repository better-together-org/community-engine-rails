
# Dokku Deployment

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
dokku postgres:create communityengine --image imresamu/postgis --image-version latest
```

Link your new postgres instance to your applciation:

```bash
dokku postgres:link communityengine communityengine
```

# Redis

This app uses Redis for the background job queue.

Visit the dokku-redis GitHub repo for installation and usage instructions:

https://github.com/dokku/dokku-redis

Create the redis instance with support for postGIS:

```bash
dokku redis:create communityengine
```

Link your new redis instance to your applciation:

```bash
dokku redis:link communityengine communityengine
```

## Set build variables

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
