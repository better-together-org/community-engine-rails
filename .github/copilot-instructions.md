# Better Together Community Engine – Rails App & Engine Guidelines

This repository contains the **Better Together Community Engine** (an isolated Rails engine under the `BetterTogether` namespace) and/or a host Rails app that mounts it. Use these instructions for all code generation.

## Core Principles

- **Security first**: Run `bundle exec brakeman --quiet --no-pager` before generating code; fix high-confidence vulnerabilities
- **Accessibility first** (WCAG AA/AAA): semantic HTML, ARIA roles, keyboard nav, proper contrast.
- **Hotwire everywhere**: Turbo for navigation/updates; Stimulus controllers for interactivity.
- **Keep controllers thin**; move business logic to POROs/service objects or concerns.
- **Prefer explicit join models** over polymorphic associations when validation matters.
- **Avoid the term "STI"** in code/comments; use "single-table inheritance" or alternate designs.
- **Use `ENV.fetch`** rather than `ENV[]`.
- **Always add policy/authorization checks** on links/buttons to controller actions.
- **i18n & Mobility**: every user-facing string must be translatable; include missing keys.
- Provide translations for all available locales (e.g., en, es, fr) when adding new strings.

## Technology Stack

- **Rails 7.1+** (engine & current hosts) – compatible with Rails 8 targets
- **Ruby 3.3+**
- **PostgreSQL (+ PostGIS, pgcrypto)**
- **Redis** for caching & Sidekiq queues
- **Sidekiq** for background jobs (queue namespaced, e.g. `:metrics`)
- **Hotwire (Turbo, Stimulus)**
- **Bootstrap 5.3 & Font Awesome 6** (not Tailwind)
- **Trix / Action Text** for rich text
- **Active Record Encryption** for sensitive fields; encrypted Active Storage files
- **Mobility** for attribute translations
- **Elasticsearch 7** via `elasticsearch-rails`
- **Importmap-Rails** for JS deps (no bundler by default)
- **Dokku** (Docker-based PaaS) for deployment; Cloudflare for DNS/DDoS/tunnels
- **AWS S3 / MinIO** for file storage (transitioning to self-hosted MinIO)
- **Action Mailer + locale-aware emails**
- **Noticed** for notifications

> Dev DB: PostgreSQL (not SQLite). Production: PostgreSQL. PostGIS enabled for geospatial needs.

## Documentation & Diagrams Policy

- For any new functionality, routes, background jobs, or changes to models/associations:
  - Update or add documentation under `docs/` describing the behavior and flows.
  - Maintain Mermaid diagrams (`.mmd`) reflecting new or changed relationships and process flows.
  - Regenerate PNGs from `.mmd` sources using `bin/render_diagrams`.
- Ensure PRs include docs/diagrams updates when applicable; missing updates should be treated as a review blocker.
- When modifying exchange (Joatu) features (Offers, Requests, Agreements, Notifications), keep both the process doc and flow diagram in sync.

### System Documentation Requirements

- **Follow Documentation Standards**: Use `docs/system_documentation_template.md` for comprehensive system documentation
- **Progress Tracking**: Review `docs/documentation_assessment.md` for current priorities and completion status
- **Quality Standards**: Each system documentation must include:
  - Minimum 200 lines technical documentation covering architecture, implementation, and usage
  - Process flow diagram with Mermaid source (.mmd) + high-resolution PNG + optimized SVG
  - Complete database schema coverage with table relationships and field descriptions
  - Implementation examples with code snippets and configuration examples
  - Performance considerations, caching strategies, and optimization techniques
  - Security implications, access controls, and data protection measures
  - API endpoint documentation with request/response examples
  - Monitoring tools, debugging guides, and troubleshooting procedures
  - Integration points showing dependencies and system interactions

### Documentation Progress Updates

- **After System Completion**: Run `docs/update_progress.sh` to update completion metrics and assessment timestamps
- **Assessment Updates**: Update `docs/documentation_assessment.md` progress matrix when completing major system documentation
- **Priority Focus**: Prioritize High Priority systems (Community, Content Management, Communication) before Medium/Low priority systems
- **Template Consistency**: Always use the standardized template to ensure comprehensive coverage and consistent quality across all system documentation


## Coding Guidelines

### Security Requirements
- **Run Brakeman before generating code**: `bundle exec brakeman --quiet --no-pager` 
- **Fix high-confidence vulnerabilities immediately** - never ignore security warnings with "High" confidence
- **Review and address medium-confidence warnings** that are security-relevant
- **Safe coding practices when generating code:**
  - **No unsafe reflection**: Never use `constantize`, `safe_constantize`, or `eval` on user input
  - **Use allow-lists for dynamic class resolution**: Follow the `joatu_source_class` pattern with concern-based allow-lists
  - **Validate user inputs**: Always sanitize and validate parameters, especially for file uploads and dynamic queries
  - **Strong parameters**: Use Rails strong parameters in all controllers
  - **Authorization everywhere**: Implement Pundit policy checks on all actions
  - **SQL injection prevention**: Use parameterized queries, avoid string interpolation in SQL
  - **XSS prevention**: Use Rails auto-escaping, sanitize HTML inputs with allowlists
- **For reflection-based features**: Create concerns with `included_in_models` class methods for safe dynamic class resolution
- **Post-generation security check**: Run `bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after major code changes

## Test Environment Setup
- Configure the host Platform in a before block for controller/request/feature tests.
  - Create/set a Platform as host (with community) before requests.
  - Toggle requires_invitation and provide invitation_code when needed.

- **Ruby/Rails**
  - 2-space indent, snake_case methods, Rails conventions
  - Service objects in `app/services/`
  - Concerns for reusable model/controller logic
  - Strong params, Pundit/Policy checks (or equivalent) everywhere
  - Avoid fat callbacks; keep models lean
- **Views**
  - ERB with semantic HTML
  - Bootstrap utility classes; respect prefers-reduced-motion & other a11y prefs
  - Avoid inline JS; use Stimulus
  - External links in `.trix-content` get FA external-link icon unless internal/mailto/tel/pdf
  - All user-facing copy must use t("...") and include keys across all locales (add to config/locales/en.yml, es.yml, fr.yml).
- **Hotwire**
  - Use Turbo Streams for CRUD updates
  - Stimulus controllers in `app/javascript/controllers/`
  - No direct DOM manipulation without Stimulus targets/actions
- **Background Jobs**
  - Sidekiq jobs under appropriate queues (`:default`, `:mailers`, `:metrics`, etc.)
  - Idempotent job design; handle retries
  - When generating emails/notifications, localize both subject and body for all locales.
- **Search**
  - Update `as_indexed_json` to include translated/plain-text fields as needed
- **Encryption & Privacy**
  - Use AR encryption for sensitive columns
  - Ensure blobs are encrypted at rest
- **Testing**
  - RSpec (if present) or Minitest – follow existing test framework
  - **Generate comprehensive test coverage for all changes**: Every modification must include RSpec tests covering the new functionality
  - All RSpec specs **must use FactoryBot factories** for model instances (do not use `Model.create` or `Model.new` directly in specs).
  - **A FactoryBot factory must exist for every model**. When generating a new model, also generate a factory for it.
  - **Factories must use the Faker gem** to provide realistic, varied test data for all attributes (e.g., names, emails, addresses, etc.).
  - **Test all layers**: models, controllers, mailers, jobs, JavaScript/Stimulus controllers, and integration workflows
  - System tests for Turbo flows where possible
  - **Session-based testing**: When working on existing code modifications, generate tests that cover all unstaged changes and related functionality

## Test Generation Strategy

### Mandatory Test Creation
When modifying existing code or adding new features, always generate RSpec tests that provide comprehensive coverage:

1. **Model Tests**: 
   - Validations, associations, scopes, callbacks
   - Instance methods, class methods, delegations
   - Business logic and calculated attributes
   - Security-related functionality (encryption, authorization)

2. **Controller Tests**:
   - All CRUD actions and custom endpoints
   - Authorization policy checks (Pundit/equivalent)
   - Parameter handling and strong params
   - Response formats (HTML, JSON, Turbo Stream)
   - Error handling and edge cases

3. **Background Job Tests**:
   - Job execution and success scenarios
   - Retry logic and error handling
   - Side effects and state changes
   - Queue assignment and timing

4. **Mailer Tests**:
   - Email content and formatting
   - Recipient handling and localization
   - Attachment and delivery configurations
   - Multi-locale support

5. **JavaScript/Stimulus Tests**:
   - Controller initialization and teardown
   - User interaction handlers
   - Form state management and dynamic updates
   - Target and action mappings

6. **Integration Tests**:
   - Complete user workflows
   - Cross-model interactions
   - End-to-end feature functionality
   - Authentication and authorization flows

### Session-Specific Test Coverage
For this codebase, ensure tests cover all recent changes including:
- Enhanced LocatableLocation model with polymorphic associations
- Event model with notification callbacks and location integration
- Calendar and CalendarEntry associations
- Event notification system (EventReminderNotifier, EventUpdateNotifier)
- Background jobs for event reminders and scheduling
- EventMailer with localized content
- Dynamic location selector JavaScript controller
- Form enhancements with location type selection

### Test Quality Standards
- Use descriptive test names that explain the expected behavior
- Follow AAA pattern (Arrange, Act, Assert) in test structure
- Mock external dependencies and network calls
- Test both success and failure scenarios
- Use shared examples for common behavior patterns
- Ensure tests are deterministic and can run independently

## Project Architecture Notes

- Engine code is namespaced under `BetterTogether`.
- Host app extends/overrides engine components where needed.
- Content blocks & page builder use configurable relationships (content areas, background images, etc.).
- Journey/Lists features use polymorphic items but with care (or explicit join models).
- Agreements system models participants, roles, terms, and timelines.

## Specialized Instruction Files

- `.github/instructions/rails_engine.instructions.md` – Engine isolation & namespacing
- `.github/instructions/hotwire.instructions.md` – Turbo/Stimulus patterns
- `.github/instructions/hotwire-native.instructions.md` – Hotwire Native patterns
- `.github/instructions/sidekiq-redis.instructions.md` – Background jobs & Redis
- `.github/instructions/search-elasticsearch.instructions.md` – Elasticsearch indexing patterns
- `.github/instructions/i18n-mobility.instructions.md` – Translations (Mobility + I18n)
- `.github/instructions/accessibility.instructions.md` – A11y checklist & patterns
- `.github/instructions/notifications-noticed.instructions.md` – Notification patterns
- `.github/instructions/deployment.instructions.md` – Dokku, Cloudflare, backups (S3/MinIO)
- `.github/instructions/security-encryption.instructions.md` – AR encryption, secrets
- `.github/instructions/bootstrap.instructions.md` – Styling, theming, icon usage
- `.github/instructions/importmaps.instructions.md` – JS dependency management
- `.github/instructions/view-helpers.instructions.md` – Consistency in Rails views

---

_If you generate code that touches any of these areas, consult the relevant instruction file and follow it._

## Internationalization & Translation Normalization
- Use the `i18n-tasks` gem to:
  - Normalize locale files (`i18n-tasks normalize`).
  - Identify and add missing keys (`i18n-tasks missing`, `i18n-tasks add-missing`).
  - Ensure all user-facing strings are present in all supported locales (en, fr, es, etc.).
  - Add new keys in English first, then translate.
  - Review translation health regularly (`i18n-tasks health`).
- All new/changed strings must be checked with `i18n-tasks` before merging.
- See `.github/instructions/i18n-mobility.instructions.md` for details.
