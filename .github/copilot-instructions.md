# Better Together Community Engine – Rails App & Engine Guidelines

This repository contains the **Better Together Community Engine** (an isolated Rails engine under the `BetterTogether` namespace) and/or a host Rails app that mounts it. Use these instructions for all code generation.

## Core Principles

- **Security first**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before generating code; fix high-confidence vulnerabilities
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
- **Docker** containerized development environment - use `bin/dc-run` for all database-dependent commands
- **Dokku** (Docker-based PaaS) for deployment; Cloudflare for DNS/DDoS/tunnels
- **AWS S3 / MinIO** for file storage (transitioning to self-hosted MinIO)
- **Action Mailer + locale-aware emails**
- **Noticed** for notifications

> Dev DB: PostgreSQL (not SQLite). Production: PostgreSQL. PostGIS enabled for geospatial needs.

## Documentation & Diagrams Policy

- For any new functionality, routes, background jobs, or changes to models/associations:
  - Update or add documentation under `docs/` describing the behavior and flows.
  - Maintain Mermaid diagrams (`.mmd`) reflecting new or changed relationships and process flows.
  - Regenerate PNGs from `.mmd` sources using `bin/render_diagrams` (exports to `docs/diagrams/exports/`).
- Ensure PRs include docs/diagrams updates when applicable; missing updates should be treated as a review blocker.
- When modifying exchange (Joatu) features (Offers, Requests, Agreements, Notifications), keep both the process doc and flow diagram in sync.

### Diagram Integration Standards

- **Link to diagrams in documentation**: Every system documentation must include links to its related diagrams
- **GitHub-compatible Mermaid rendering**: Include `.mmd` source links first for inline GitHub rendering
- **Multiple format support**: Provide links to PNG (high-resolution) and SVG (vector) exports for different use cases
- **Standard diagram linking pattern**:
  ```markdown
  ## Process Flow Diagram
  
  ```mermaid
  <!-- Include the .mmd content directly for GitHub inline rendering -->
  ```
  
  **Diagram Files:**
  - 📊 [Mermaid Source](diagrams/source/system_name_flow.mmd) - Editable source
  - 🖼️ [PNG Export](diagrams/exports/png/system_name_flow.png) - High-resolution image
  - 🎯 [SVG Export](diagrams/exports/svg/system_name_flow.svg) - Vector graphics
  ```
- **Update all existing documentation**: When adding diagrams, retrospectively add diagram links to existing system documentation
- **Maintain consistency**: Use the same naming convention for diagram files as their corresponding system documentation

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

### Docker Environment Usage
- **All database-dependent commands must use `bin/dc-run`**: This includes tests, generators, and any command that connects to PostgreSQL, Redis, or Elasticsearch
- **Dummy app commands use `bin/dc-run-dummy`**: For Rails commands that need the dummy app context (console, migrations specific to dummy app)
- **Examples of commands requiring `bin/dc-run`**:
  - Tests: `bin/dc-run bundle exec rspec`
  - Generators: `bin/dc-run rails generate model User`
  - Brakeman: `bin/dc-run bundle exec brakeman`
  - RuboCop: `bin/dc-run bundle exec rubocop`
  - **IMPORTANT**: Never use `rspec -v` - this displays version info, not verbose output. Use `--format documentation` for detailed output.
- **Examples of commands requiring `bin/dc-run-dummy`**:
  - Rails console: `bin/dc-run-dummy rails console`
  - Dummy app migrations: `bin/dc-run-dummy rails db:migrate`
  - Dummy app database operations: `bin/dc-run-dummy rails db:seed`
- **Commands that don't require bin/dc-run**: File operations, documentation generation (unless database access needed), static analysis tools that don't connect to services

### Security Requirements
- **Run Brakeman before generating code**: `bin/dc-run bundle exec brakeman --quiet --no-pager` 
- **Fix high-confidence vulnerabilities immediately** - never ignore security warnings with "High" confidence
- **Review and address medium-confidence warnings** that are security-relevant
- **Safe coding practices when generating code:**
  - **No unsafe reflection**: Never use `constantize`, `safe_constantize`, or `eval` on user input
  - **Use allow-lists for dynamic class resolution**: Follow the `joatu_source_class` pattern with concern-based allow-lists
  - **Validate user inputs**: Always sanitize and validate parameters, especially for file uploads and dynamic queries
  - **Strong parameters**: Use Rails strong parameters in all controllers
  - **Model-level permitted attributes**: Prefer defining a class method `self.permitted_attributes` on models that returns the permitted attribute array (including nested attributes). Controllers and shared resource code should call `Model.permitted_attributes` rather than hard-coding permit lists. Compose nested permitted attributes by referencing other models' `permitted_attributes` (for example: `Conversation.permitted_attributes` may include `{ messages_attributes: Message.permitted_attributes }`).
  - **Authorization everywhere**: Implement Pundit policy checks on all actions
  - **SQL injection prevention**: Use parameterized queries, avoid string interpolation in SQL
  - **XSS prevention**: Use Rails auto-escaping, sanitize HTML inputs with allowlists
- **For reflection-based features**: Create concerns with `included_in_models` class methods for safe dynamic class resolution
- **Post-generation security check**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after major code changes

### String Enum Design Standards
- **Always use string enums** for human-readable accessibility when reviewing database entries
- **Follow existing pattern**: Use full English words as enum values (current average: ~7 characters)
- **Stored values must be human-recognizable** as representing the exact word they relate to
- **Never abbreviate unless word exceeds reasonable length** (>10 characters)
- **Never change existing enum values** unless explicitly directed to do so
- **Implementation pattern**:
  ```ruby
  # Good: Full English words (follows existing pattern)
  enum status: { 
    pending: "pending", 
    accepted: "accepted", 
    rejected: "rejected" 
  }
  
  # Good: Short and descriptive
  enum privacy: { 
    public: "public", 
    private: "private" 
  }
  
  # Good: Clear urgency levels
  enum urgency: {
    low: "low",
    normal: "normal", 
    high: "high",
    critical: "critical"
  }
  
  # Bad: Integer enums (not human-readable)
  enum status: { pending: 0, accepted: 1, rejected: 2 }
  ```
- **Database benefits**: Enum values are immediately understandable when viewing raw database entries
- **Debugging advantages**: Log entries and database queries show meaningful string values instead of integers

### Migration Standards
- **Always use Better Together migration helpers** from `lib/better_together/` modules
- **`create_bt_table`**: Creates standardized tables with UUID primary keys, lock_version, timestamps, and `better_together_` prefix
- **`bt_*` column helpers**: Use standardized column definitions for consistency across the engine
- **Common bt_* helpers**:
  - `bt_references` - UUID foreign key references with automatic constraints
  - `bt_identifier` - Unique identifier strings for translated records
  - `bt_privacy` - Privacy level columns with proper defaults  
  - `bt_community`, `bt_creator` - Standard relationship columns
- **Migration example**:
  ```ruby
  class CreateBetterTogetherReports < ActiveRecord::Migration[7.1]
    def change
      create_bt_table :reports do |t|
        t.bt_references :reporter, target_table: :better_together_people, null: false
        t.bt_references :reportable, polymorphic: true, null: false
        t.string :status, default: "pending", null: false
        t.text :reason, null: false
        t.text :resolution_notes
        t.datetime :resolved_at
        
        t.index :status
      end
    end
  end
  ```

## Test Environment Setup
- **CRITICAL**: Configure the host Platform in a before block for ALL controller/request/feature tests.
  - **Use `configure_host_platform`**: Call this helper method which creates/sets a Platform as host (with community) before HTTP requests.
  - **Include DeviseSessionHelpers**: Use authentication helpers like `login('user@example.com', 'password')` for authenticated tests.
  - **Required Pattern**:
    ```ruby
    RSpec.describe BetterTogether::SomeController, type: :controller do
      include DeviseSessionHelpers
      routes { BetterTogether::Engine.routes }
      
      before do
        configure_host_platform  # Creates host platform with community
        login('user@example.com', 'password')  # For authenticated actions
      end
    end
    ```
  - **Engine Routing**: Engine controller tests require `routes { BetterTogether::Engine.routes }` directive.
  - **Locale Parameters**: Include `locale: I18n.default_locale` in params for engine routes due to routing constraints.
  - **Rails-Controller-Testing**: Add `gem 'rails-controller-testing'` to Gemfile for `assigns` method in controller tests.
  - Toggle requires_invitation and provide invitation_code when needed for registration tests.

### Automatic test configuration & auth helper patterns

This repository provides an automatic test-configuration layer (see `spec/support/automatic_test_configuration.rb`) that sets up the host `Platform` and, where appropriate, performs authentication for request, controller, and feature specs so most specs do NOT need to call `configure_host_platform` manually.

- Automatic setup applies to specs with `type: :request`, `type: :controller`, and `type: :feature` by default.
- Use these example metadata tags to control authentication explicitly:
  - `:as_platform_manager` or `:platform_manager` — login as the platform manager (elevated privileges)
  - `:as_user`, `:authenticated`, or `:user` — login as a regular user
  - `:no_auth` or `:unauthenticated` — ensure no authentication is performed for the example
  - `:skip_host_setup` — skip host platform creation/configuration for this example

How it works:
- The test helper inspects example metadata and description text (describe/context). If the description contains keywords such as "platform manager", "admin", "authenticated", or "signed in", it will automatically set appropriate tags and perform the corresponding authentication.
- The helper creates a host `Platform` if one does not exist and marks the default setup wizard as completed.
- For request specs it uses HTTP login helpers (`login(email, password)`); for controller specs it uses Devise test helpers (`sign_in`); for feature specs it uses Capybara UI login flows.

Recommended usage:
- Prefer using metadata tags (`:as_platform_manager`, `:as_user`, `:skip_host_setup`) in the `describe` or `context` header when a test needs a specific authentication state. Example:

```ruby
RSpec.describe 'Creating a conversation', type: :request, :as_user do
  # host platform and user login are automatically configured
end
```

- Avoid calling `configure_host_platform` manually in most specs; reserve manual calls for special cases (use `:skip_host_setup` to opt out of automatic config).

Note: The helper set lives under `spec/support/automatic_test_configuration.rb` and provides helpers like `configure_host_platform`, `find_or_create_test_user`, and `capybara_login_as_platform_manager` to use directly if needed by unusual tests.

### Testing Architecture Standards
- **Project Standard**: Use request specs (`type: :request`) for all controller testing to maintain consistency
- **Request Specs Advantages**: Handle Rails engine routing automatically through full HTTP stack
- **Controller Specs Issues**: Require special URL helper configuration in Rails engines and should be avoided
- **Architectural Consistency**: The project follows request spec patterns throughout - maintain this consistency
- **Route Naming Convention**: All engine routes use full resource naming (e.g., `person_blocks_path`, not `blocks_path`)
- **URL Helper Debugging**: If you encounter `default_url_options` errors in a spec while others pass, check if it's a controller spec that should be converted to a request spec

### Rails Engine Testing Patterns
- **Standard Pattern**: Use request specs for testing engine controllers
- **Path Helpers**: Always use complete, properly namespaced path helpers (`better_together.resource_name_path`)
- **Response Assertions**: For redirects, use pattern matching instead of path helpers in specs:
  ```ruby
  # Preferred in specs
  expect(response.location).to include('/person_blocks')
  
  # Avoid in controller specs (problematic with engines)
  expect(response).to redirect_to(person_blocks_path)
  ```
- **Factory Requirements**: Every Better Together model needs a corresponding FactoryBot factory with proper engine namespace handling
