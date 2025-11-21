# Development Setup Guide

**Target Audience:** Developers  
**Document Type:** Technical Setup Guide  
**Last Updated:** November 20, 2025

## Overview

This guide walks you through setting up a local development environment for the Better Together Community Engine Rails application and engine.

## Prerequisites

### Required Software

- **Ruby**: 3.4.4 (managed via rbenv)
- **Node.js**: 20.x
- **PostgreSQL**: 14+ with PostGIS extension
- **Redis**: For caching and Sidekiq
- **Elasticsearch**: 7.17.23 (for search functionality)
- **Docker & Docker Compose**: For containerized development

### Operating System

The project is developed and tested on Linux. macOS and WSL2 (Windows) should also work with minor adjustments.

## Quick Start with Docker

The recommended development approach uses Docker Compose to manage all services.

### 1. Clone the Repository

```bash
git clone https://github.com/better-together-solutions/community-engine-rails.git
cd community-engine-rails
```

### 2. Start Services

```bash
# Start all services (PostgreSQL, Redis, Elasticsearch, Rails)
docker-compose up -d

# Check service status
docker-compose ps
```

### 3. Setup Database

```bash
# Run migrations
bin/dc-run rails db:create db:migrate

# Run dummy app migrations
bin/dc-run-dummy rails db:migrate

# Seed data (optional)
bin/dc-run-dummy rails db:seed
```

### 4. Run Tests

```bash
# Run full test suite
bin/dc-run bin/ci

# Run specific spec file
bin/dc-run bundle exec rspec spec/models/better_together/person_spec.rb

# Run tests with documentation format
bin/dc-run bundle exec rspec --format documentation
```

### 5. Access the Application

The dummy application will be available at:
- **Web**: http://localhost:3000
- **Sidekiq**: http://localhost:3000/sidekiq

## Development Workflow

### Running Commands

All database-dependent commands must use `bin/dc-run` or `bin/dc-run-dummy`:

```bash
# Engine commands (most development work)
bin/dc-run bundle exec rspec
bin/dc-run rails generate model User
bin/dc-run bundle exec rubocop

# Dummy app commands (for testing the engine in host context)
bin/dc-run-dummy rails console
bin/dc-run-dummy rails db:migrate
bin/dc-run-dummy rails server
```

### Code Quality

```bash
# Run linter with auto-fix
bin/dc-run bundle exec rubocop -A

# Run security scanner
bin/dc-run bundle exec brakeman --quiet --no-pager

# Check dependencies for vulnerabilities
bin/dc-run bundle exec bundler-audit --update

# Run style guard
bin/dc-run bin/codex_style_guard
```

### I18n Management

```bash
# Normalize locale files
bin/dc-run bin/i18n normalize

# Check for missing translations
bin/dc-run bin/i18n check

# Run all i18n checks
bin/dc-run bin/i18n all
```

### Diagram Rendering

```bash
# Render all Mermaid diagrams to PNG/SVG
bin/render_diagrams

# Force re-render all diagrams
bin/render_diagrams --force
```

## Manual Setup (Without Docker)

If you prefer manual setup:

### 1. Install Ruby

```bash
# Install rbenv and ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Add to shell profile
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby 3.4.4
rbenv install 3.4.4
rbenv global 3.4.4
```

### 2. Install Node.js

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install Node 20
nvm install 20
nvm use 20
```

### 3. Install PostgreSQL with PostGIS

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-14 postgresql-14-postgis-3

# macOS
brew install postgresql@14 postgis
```

### 4. Install Redis

```bash
# Ubuntu/Debian
sudo apt-get install redis-server

# macOS
brew install redis
```

### 5. Install Elasticsearch

```bash
# Download and install Elasticsearch 7.17.23
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.23-linux-x86_64.tar.gz
tar -xzf elasticsearch-7.17.23-linux-x86_64.tar.gz
cd elasticsearch-7.17.23
./bin/elasticsearch -d
```

### 6. Setup Application

```bash
# Install dependencies
bundle install
npm install

# Setup databases
rails db:create db:migrate
cd spec/dummy && rails db:migrate

# Run tests
bundle exec rspec
```

## Environment Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Database
DATABASE_URL=postgresql://localhost/community_engine_development

# Redis
REDIS_URL=redis://localhost:6379/0

# Elasticsearch
ELASTICSEARCH_URL=http://localhost:9200

# Rails
RAILS_ENV=development
SECRET_KEY_BASE=your_secret_key_here

# Optional: External services
# SMTP_ADDRESS=smtp.example.com
# SMTP_PORT=587
# SMTP_USERNAME=your_username
# SMTP_PASSWORD=your_password
```

### Database Configuration

The `config/database.yml` uses `DATABASE_URL` environment variable. For local development:

```bash
export DATABASE_URL="postgresql://localhost/community_engine_development"
```

## Common Development Tasks

### Creating a New Feature

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Generate models/controllers**
   ```bash
   bin/dc-run rails generate model BetterTogether::YourModel
   bin/dc-run rails generate controller BetterTogether::YourModels
   ```

3. **Write tests first** (TDD approach)
   ```bash
   # Create spec file
   bin/dc-run bundle exec rspec spec/models/better_together/your_model_spec.rb
   ```

4. **Run security checks**
   ```bash
   bin/dc-run bundle exec brakeman --quiet --no-pager
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "Add your feature"
   git push origin feature/your-feature-name
   ```

### Running Background Jobs

```bash
# Start Sidekiq
bin/dc-run bundle exec sidekiq

# Monitor Sidekiq web UI
# Visit http://localhost:3000/sidekiq
```

### Debugging

**Never use Rails console for debugging.** Use comprehensive test suites instead:

```bash
# Write specific tests to reproduce issues
bin/dc-run bundle exec rspec spec/path/to/failing_spec.rb

# Add debugging output in tests temporarily
# Use --format documentation for detailed output
bin/dc-run bundle exec rspec --format documentation
```

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Restart PostgreSQL
docker-compose restart postgres

# Reset database
bin/dc-run rails db:drop db:create db:migrate
```

### Redis Connection Issues

```bash
# Check Redis is running
docker-compose ps redis

# Restart Redis
docker-compose restart redis
```

### Elasticsearch Issues

```bash
# Check Elasticsearch is running
curl http://localhost:9200

# Restart Elasticsearch
docker-compose restart elasticsearch

# Reindex search
bin/dc-run rails searchkick:reindex:all
```

### Test Failures

```bash
# Run tests with specific seed
bin/dc-run bundle exec rspec --seed 12345

# Run specific test line
bin/dc-run bundle exec rspec spec/models/user_spec.rb:25

# Clear test database and retry
bin/dc-run rails db:test:prepare
```

## Additional Resources

- [Contributing Guide](../../CONTRIBUTING.md)
- [Code of Conduct](../../CODE_OF_CONDUCT.md)
- [Security Policy](../../SECURITY.md)
- [Architecture Documentation](../developers/architecture/)
- [System Documentation](../developers/systems/)

## Getting Help

- **Documentation**: Check this guide and related docs
- **Issues**: Search [GitHub Issues](https://github.com/better-together-solutions/community-engine-rails/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/better-together-solutions/community-engine-rails/discussions)
- **Community**: Join the Better Together community for support

## Next Steps

After setup:

1. **Read the architecture docs** - Understand the system design
2. **Review existing code** - Familiarize yourself with patterns
3. **Pick an issue** - Start with "good first issue" labels
4. **Write tests** - Always use TDD approach
5. **Submit PR** - Follow contribution guidelines

---

**Remember:** This is a Rails engine project. Most development happens in the engine code, with the dummy app (`spec/dummy`) used for testing the engine in a host application context.
