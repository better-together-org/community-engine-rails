# Swagger API Documentation - Deployment Guide

## Overview

The Swagger/OpenAPI documentation is generated from RSpec request specs using the `rswag` gem. The generated `swagger.yaml` file needs to be environment-aware for correct server URLs in production.

## Problem

The `swagger/v1/swagger.yaml` file is static and pre-generated. If committed with development URLs, it won't reflect production environment configuration.

## Solution: Generate During Deployment

### Dokku Deployment

Add swagger generation to your deployment process by creating a `postdeploy` script or adding to your existing deployment hooks.

#### Option 1: Using Dokku postdeploy

Create or update `.dokku/scripts/postdeploy`:

```bash
#!/usr/bin/env bash
set -eo pipefail

# Generate swagger documentation with production URLs
echo "-----> Generating Swagger documentation"
bundle exec rake swagger:generate

# Other deployment tasks...
bundle exec rake db:migrate
```

#### Option 2: Using Procfile release phase

If using a `Procfile.release`:

```yaml
release: bundle exec rake db:migrate swagger:generate
```

### GitHub Actions / CI

Add to your CI workflow to ensure swagger is always up-to-date:

```yaml
# .github/workflows/deploy.yml
- name: Generate Swagger Documentation
  run: |
    export RAILS_ENV=production
    bin/dc-run bundle exec rake swagger:generate
```

### Manual Generation

#### Development
```bash
# Generate with development URLs
bin/swagger_generate

# Or directly:
bin/dc-run bundle exec rake swagger:generate
```

#### Production
```bash
# Generate with production URLs
RAILS_ENV=production bin/swagger_generate

# Or directly:
RAILS_ENV=production bin/dc-run bundle exec rake swagger:generate
```

## Validation

Verify swagger documentation matches current environment:

```bash
bin/dc-run bundle exec rake swagger:validate
```

This will check if the generated swagger.yaml contains the correct server URL for the current environment.

## Git Strategy

### Option A: Don't Commit (Recommended for Production)

Add to `.gitignore`:
```
swagger/v1/swagger.yaml
```

Generate during deployment only. This ensures it's always current for the environment.

### Option B: Commit Development Version

- Commit the development version for local API testing
- Regenerate during production deployment
- Add validation to CI to ensure it's up-to-date

```yaml
# .github/workflows/test.yml
- name: Validate Swagger Documentation
  run: bin/dc-run bundle exec rake swagger:validate
```

## Configuration

The swagger helper uses `BetterTogether.base_url` which should be configured per environment:

```ruby
# config/initializers/better_together.rb (or similar)
BetterTogether.configure do |config|
  config.base_url = ENV.fetch('BASE_URL', 'http://localhost:3000')
end
```

### Environment Variables

Set in Dokku:
```bash
dokku config:set your-app BASE_URL=https://your-production-domain.com
```

## Testing

When writing API request specs, ensure they generate proper swagger documentation:

```ruby
# spec/requests/api/v1/your_resource_spec.rb
require 'swagger_helper'

RSpec.describe 'API V1 YourResource', type: :request do
  path '/api/v1/your_resources' do
    get 'List resources' do
      tags 'YourResource'
      produces 'application/vnd.api+json'
      
      # ... rest of spec
    end
  end
end
```

After adding new specs:
```bash
bin/swagger_generate
```

## Troubleshooting

### Server URL is wrong

1. Check `BASE_URL` environment variable
2. Regenerate swagger: `RAILS_ENV=production bin/swagger_generate`
3. Verify with: `bin/dc-run bundle exec rake swagger:validate`

### Swagger out of date

Run after any API spec changes:
```bash
bin/swagger_generate
```

### Deployment not generating swagger

1. Verify rake task runs during deployment
2. Check deployment logs for errors
3. Ensure all required gems are installed in production

## Related Files

- `spec/swagger_helper.rb` - Swagger configuration and server URL logic
- `lib/tasks/swagger.rake` - Rake tasks for generation and validation
- `bin/swagger_generate` - Convenience script for manual generation
- `swagger/v1/swagger.yaml` - Generated OpenAPI documentation
