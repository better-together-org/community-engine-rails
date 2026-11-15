# Better Together Community Engine

A Rails engine for building community platforms: communities, membership, events, posts, pages, messaging and mutual aid exchanges, with privacy, safety and member data rights built in. You add the `better_together` gem to a Rails app (the *host app*) and it provides the platform; the host app supplies branding, deployment and any custom features.

![A Community Engine community page with a branded banner, a request-to-join control, tabs for About, Posts and Events, and share buttons](docs/screenshots/desktop/community_access_mode_request_to_join.png)

## Is it the right fit?

**A good fit if you want to:**

- run a community, co-operative, non-profit or civic site where members sign in, join communities, attend events, post and message each other, and organizers moderate;
- host several organizations or sites from one install, each with its own domain, theme, members and storage (multi-tenant platforms);
- keep control of your data: self-hosted, Postgres-backed, with member data export and deletion, and optional federation with other platforms by consent;
- start from working social, content and governance features and extend them in a normal Rails app.

**Probably not a fit if you:**

- need a static brochure site or a blog only (a static site generator is simpler);
- are not using, or do not want to run, Rails, PostgreSQL with PostGIS and Redis;
- want a drop-in SaaS with no hosting or upgrade work: a host app needs maintenance, and each release has an upgrade guide.

## What it provides

- **Communities and membership.** Communities with public, private or request-to-join access, an organizer review queue, invitations, roles and permissions. See [community management](docs/platform_organizers/community_management.md) and the [membership request workflow](docs/developers/systems/membership_request_workflow.md).
- **Content.** A page builder with many block types, posts, an uploads gallery and image library, navigation menus, short links, Markdown and rich text, and translatable content in English, French, Spanish and Ukrainian. See the [content system](docs/developers/systems/content_management.md) and [block system](docs/developers/systems/block_system_and_cms.md).
- **Events.** Events with recurrence, invitations, RSVPs and calendars. See the [events system](docs/developers/systems/events_system.md).
- **Messaging and exchanges.** Conversations with message requests, notifications, and Joatu offers and requests for mutual aid. See [conversations and messaging](docs/developers/systems/conversations_messaging_system.md) and the [Joatu docs](docs/joatu).
- **Multi-tenant platforms.** Several platforms in one app, each with its own domains, theme, sign-in providers, storage and settings. See the [multi-tenant runtime](docs/developers/systems/multi_tenant_platform_runtime.md), [theme settings](docs/platform_organizers/theme_settings.md) and [storage configuration](docs/platform_organizers/storage_configuration_guide.md).
- **Federation.** Optional, consent-based sharing of pages, posts and events between platforms, approved by stewards. See the [federation system](docs/developers/systems/federation_system.md).
- **Safety and privacy.** Blocks enforced across messaging, events and exchanges, reporting, bot protection, rate limiting, content security scanning, agreements with an acceptance audit trail, and member data export and deletion. See the [security and protection system](docs/developers/systems/security_protection_system.md), [bot safety](docs/developers/systems/bot_safety_system.md) and [security and privacy for organizers](docs/platform_organizers/security_privacy.md).
- **Sign-in.** Devise accounts, plus Google, Facebook and OpenID Connect providers configured per platform. See [Google sign-in setup](docs/platform_organizers/google_sign_in_setup.md).
- **APIs and tooling.** A JSON:API and MCP surface for pages and posts, a seed packet format for moving content between platforms, and Postgres-native search. See the [API docs](docs/api) and [seed packet protocol](docs/developers/systems/seed_packet_protocol.md).
- **Extension gems.** Elasticsearch, Sentry and Google Analytics are separate gems that plug into the engine: [better_together-elasticsearch](https://github.com/better-together-org/better_together-elasticsearch), [better_together-sentry](https://github.com/better-together-org/better_together-sentry) and [better_together-google-analytics](https://github.com/better-together-org/better_together-google-analytics).

Version 0.11.0 is the current release. See the [0.11.0 release notes](docs/releases/0.11.0.md) for what changed and the [host upgrade guide](docs/releases/0.11.0_host_upgrade_guide.md) if you are upgrading.

## Getting started

Adding the engine to a Rails app takes a few commands, but the details differ for a new app and an existing one, so they live in one guide:

**[Installing Community Engine in a Rails app](docs/developers/host_app_installation.md)** covers requirements, the installer (`rails g better_together:install`), credentials and encryption keys, migrations and first run.

Related reading for people running a host app: [migrations from the gem](docs/developers/host_app_migrations_from_gem.md), [deploying with Dokku](docs/production/deployment-dokku.md), [platform themes in host apps](docs/developers/systems/platform_themes_host_apps.md).

## Where to read next

The [documentation index](docs/README.md) is organized by role:

- **Developers:** the [developer guide](docs/developers/README.md) and the [system docs](docs/developers/systems) (one per subsystem, with diagrams).
- **Platform organizers:** the [platform organizer guide](docs/platform_organizers/README.md).
- **Community organizers and members:** the [community organizer guide](docs/community_organizers/README.md) and [end user guide](docs/end_users/README.md).
- **Everything:** the [table of contents](docs/table_of_contents.md).

## License

Released under the GNU Lesser General Public License; see [LICENSE](LICENSE).

## Development: Getting Started

This gem is developed using Docker and Docker Compose. To get the app running, complete the following steps:

Build the application image using the docker convenience scripts:

```bash
bin/dc build
```

Bundle the gems:

```bash
bin/dc-run bundle
```

Setup the database:

```bash
bin/dc-run rails db:setup
```

Run the RSpec tests:

```bash
bin/dc-run rspec
```

Troubleshooting:

- `bin/dc-run rails db:create` only creates the databases. It does not load schema or run migrations.
- If you have already run `db:create`, run `bin/dc-run rails db:migrate` or `bin/dc-run rails db:setup` before `bin/dc-run rails db:seed`.
- Fresh worktrees may not include ignored files such as `spec/dummy/config/master.key`, so local setup must not depend on that file being present.

## Contributing

We welcome contributions from the community.

- Guidelines: See [CONTRIBUTING.md](CONTRIBUTING.md) for how to report issues, propose changes, and submit pull requests.
- Code of Conduct: See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for expectations of behavior in our community.

Thank you for helping make Better Together better for everyone.
