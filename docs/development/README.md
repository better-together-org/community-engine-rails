# Development Resources

**Target Audience:** Developers  
**Purpose:** Development setup, tools, and workflows

## Getting Started

- [🛠️ Development Setup](dev-setup.md) - Complete local development environment setup guide

## Quick Links

- [Main README](../README.md) - Documentation overview
- [Developer Documentation](../developers/README.md) - System and architecture docs
- [Contributing Guide](../../CONTRIBUTING.md) - How to contribute
- [Security Policy](../../SECURITY.md) - Reporting security issues

## Development Tools

### Required Tools
- Ruby 3.4.4 via rbenv
- Node.js 20.x
- PostgreSQL 14+ with PostGIS
- Redis (for caching and Sidekiq)
- Elasticsearch 7.17.23
- Docker & Docker Compose

### Development Commands

```bash
# Run tests
bin/dc-run bin/ci

# Lint code
bin/dc-run bundle exec rubocop -A

# Security scan
bin/dc-run bundle exec brakeman --quiet --no-pager

# I18n management
bin/dc-run bin/i18n all

# Render diagrams
bin/render_diagrams
```

## Development Workflow

1. **Setup**: Follow [dev-setup.md](dev-setup.md)
2. **Branch**: Create feature branch
3. **Test**: Write tests first (TDD)
4. **Code**: Implement feature
5. **Verify**: Run tests and quality checks
6. **Commit**: Submit pull request

## Related Documentation

- [Architecture](../developers/architecture/) - System architecture
- [Systems](../developers/systems/) - Feature documentation
- [Implementation Templates](../implementation/templates/) - Project templates
- [Diagram Sources](../diagrams/source/) - Visual documentation

---

**Note:** This is a Rails engine project. Most development occurs in the engine code, with spec/dummy used for testing.
