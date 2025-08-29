# AGENTS.md

Instructions for GitHub Copilot and other automated contributors working in this repository.

## Project
- Ruby: 3.4.4 (installed via rbenv in setup)
- Rails: 7.1
- Node: 20
- DB: PostgreSQL + PostGIS
- Search: Elasticsearch 7.17.23
- Test app: `spec/dummy`

## Setup
- Environment runs a setup script that installs Ruby 3.4.4, Node 20, Postgres + PostGIS, and ES7, then prepares databases.
- **Docker Environment**: All commands requiring database access must use `bin/dc-run` to execute within the containerized environment.
- **Dummy App Commands**: Use `bin/dc-run-dummy` for Rails commands that need the dummy app context (e.g., `bin/dc-run-dummy rails console`, `bin/dc-run-dummy rails db:migrate`).
- Databases:
  - development: `community_engine_development`
  - test: `community_engine_test`
- Use `DATABASE_URL` to connect (overrides fallback host in `config/database.yml`).

## Commands
- **Tests:** `bin/dc-run bin/ci`
  (Equivalent: `bin/dc-run bash -c "cd spec/dummy && bundle exec rspec"`)
- **Running specific tests:** 
  - Single spec file: `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb`
  - Specific line: `bin/dc-run bundle exec rspec spec/path/to/file_spec.rb:123`
  - Multiple files: `bin/dc-run bundle exec rspec spec/file1_spec.rb spec/file2_spec.rb`
  - Multiple specific lines: `bin/dc-run bundle exec rspec spec/file1_spec.rb:123 spec/file2_spec.rb:456`
  - **Important**: RSpec does NOT support hyphenated line numbers (e.g., `spec/file_spec.rb:123-456` is INVALID)
  - **Do NOT use `-v` flag**: The `-v` flag displays RSpec version information, NOT verbose output. Use `--format documentation` for detailed test descriptions.
- **Rails Console:** `bin/dc-run-dummy rails console` (runs console in the dummy app context)
- **Rails Commands in Dummy App:** `bin/dc-run-dummy rails [command]` for any Rails commands that need the dummy app environment
- **Lint:** `bin/dc-run bundle exec rubocop`
- **Security:** `bin/dc-run bundle exec brakeman --quiet --no-pager` and `bin/dc-run bundle exec bundler-audit --update`
- **Style:** `bin/dc-run bin/codex_style_guard`
- **I18n:** `bin/dc-run bin/i18n [normalize|check|health|all]` (runs normalize + missing + interpolation checks by default)
- **Documentation:**
  - **Table of Contents**: [`docs/table_of_contents.md`](docs/table_of_contents.md) - Main documentation index
  - **Progress tracking**: `docs/scripts/update_progress.sh` - Update system completion status
  - **Diagram rendering**: `bin/render_diagrams` - Generate PNG/SVG from Mermaid sources
  - **Validation**: `docs/scripts/validate_documentation_tooling.sh` - Validate doc system integrity

## Security Requirements
- **Run Brakeman before generating code**: `bin/dc-run bundle exec brakeman --quiet --no-pager` 
- **Fix high-confidence vulnerabilities immediately** - never ignore security warnings with "High" confidence
- **Review and address medium-confidence warnings** that are security-relevant
- **Safe coding practices when generating code:**
  - Never use `constantize`, `safe_constantize`, or `eval` on user input
  - Use allow-lists for dynamic class resolution (see `joatu_source_class` pattern)
  - Sanitize and validate all user inputs
  - Use strong parameters in controllers
  - Implement proper authorization checks (Pundit policies)
- **For reflection-based features**: Create concerns with `included_in_models` class methods for safe dynamic class resolution
- **Post-generation security check**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after major code changes

## Conventions
- Make incremental changes with passing tests.
- **Security first**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before committing code changes.
- **Test every change**: Generate RSpec tests for all code modifications, including models, controllers, mailers, jobs, and JavaScript.
- **Test coverage requirements**: All new features, bug fixes, and refactors must include comprehensive test coverage.
- Avoid introducing new external services in tests; stub where possible.
- If RuboCop reports offenses after autocorrect, update and rerun until clean.
- Keep commit messages and PR descriptions concise and informative.

## String Enum Design Standards
- **Always use string enums** for human-readable accessibility when reviewing database entries.
- **Follow existing pattern**: Use full English words as enum values (current average: ~7 characters).
- **Stored values must be human-recognizable** as representing the exact word they relate to.
- **Never abbreviate unless word exceeds reasonable length** (>10 characters).
- **Examples from existing codebase**:
  - `status: { pending: "pending", accepted: "accepted", rejected: "rejected" }`
  - `privacy: { public: "public", private: "private" }`
  - `urgency: { low: "low", normal: "normal", high: "high", critical: "critical" }`
- **Never change existing enum values** unless explicitly directed to do so.

## Migration Standards
- **Use Better Together migration helpers** from `lib/better_together/` modules for all database changes
- **`create_bt_table`**: Creates tables with UUID primary keys, lock_version, timestamps, and proper naming conventions
- **`bt_*` column helpers**: Use standardized column definitions (bt_references, bt_identifier, bt_privacy, etc.)
- **Consistent naming**: All tables automatically prefixed with `better_together_`
- **UUID foreign keys**: Use `bt_references` for all associations to maintain consistency
- **Example migration pattern**:
  ```ruby
  class CreateBetterTogetherExampleModel < ActiveRecord::Migration[7.1]
    def change
      create_bt_table :example_models do |t|
        t.bt_identifier
        t.bt_privacy
        t.bt_references :person, null: false
        t.string :status, default: "pending"
      end
    end
  end
  ```

## Documentation & Diagrams
- Always update documentation when adding new functionality or changing data relationships.
  - For new features or flows: add/update a process doc under `docs/` that explains intent, actors, states, and key branch points.
  - For model/association changes: update Mermaid diagrams (e.g., `docs/diagrams/source/*_diagram.mmd` or add a new one).
- Keep diagrams in Mermaid (`.mmd`) format in `docs/diagrams/source/` and render to exports for convenience.
  - Preferred: run `bin/render_diagrams` to regenerate images for all `docs/diagrams/source/*.mmd` files.
  - Fallback: `npx -y @mermaid-js/mermaid-cli -i docs/diagrams/source/your_diagram.mmd -o docs/diagrams/exports/png/your_diagram.png`.
- PRs that add/modify models, associations, or flows must include corresponding docs and diagrams.
- When notifications, policies, or routes change, ensure affected docs and diagrams are updated to match behavior.

## Documentation Progress Tracking
- **System Documentation Standards**: Follow the template in `docs/system_documentation_template.md` for comprehensive system documentation.
- **Documentation Assessment**: Review `docs/documentation_assessment.md` for current progress and priorities.
- **Progress Updates**: Run `docs/update_progress.sh` after completing system documentation to update metrics.
- **Quality Requirements**: Each system must include:
  - Minimum 200 lines comprehensive technical documentation
  - Process flow diagram with Mermaid source (.mmd) + PNG/SVG outputs
  - Database schema coverage with table relationships
  - Implementation examples with code snippets
  - Performance and security considerations
  - API endpoint documentation where applicable
  - Troubleshooting guides and monitoring tools
- **Documentation Phases**: Prioritize High Priority systems first (Community, Content, Communication), then Medium/Low priority systems.
- **Assessment Updates**: Update `docs/documentation_assessment.md` when completing system documentation or major milestones.

## Platform Registration Mode
- Invitation-required: Platforms support `requires_invitation` (see `BetterTogether::Platform#settings`). When enabled, users must supply a valid invitation code to register. This is the default for hosted deployments.
- Where to change: Host Dashboard → Platforms → Edit → “Requires Invitation”.
- Effects:
  - Devise registration page prompts for an invitation code when none is present.
  - Accepted invitations prefill email, apply community/platform roles, and are marked accepted on successful sign‑up.

## Privacy Practices for Platform Organizers
- Default posture: keep `requires_invitation` enabled unless there is a clear, consented need to open registration.
- Privacy policy: publish and maintain a platform‑specific privacy policy; disclose any third‑party trackers (e.g., GA, Sentry) and their purposes.
- Consent/cookies: add a cookie/consent banner before enabling third‑party trackers; anonymize IPs; disable ad personalization; respect regional requirements.
- Data minimization:
  - Avoid placing PII in URLs, block identifiers, or public content.
  - Do not add user identifiers to metrics — the engine’s built‑in metrics are event‑only by design.
- Retention & deletion:
  - Define retention periods for metrics and exports (e.g., 90 days for CSV exports; 180 days for raw events).
  - Regularly purge report files (Active Storage) and delete old metrics in batches.
  - Honor data deletion requests: remove user content and related exports; avoid exporting PII.
- Environments: do not copy production data to development/staging; use seeded, synthetic content for testing.

## Translations & Locales
- All user‑facing text must use I18n — do not hard‑code strings in views, controllers, models, or JS.
- When adding new text, add translation keys for all available locales in this repo (e.g., `config/locales/en.yml`, `es.yml`, `fr.yml`).
- Include translations for:
  - Flash messages, validation errors, button/label text, email subjects/bodies, and Action Cable payloads.
  - Any UI strings rendered from background jobs or notifiers.
- Prefer existing keys where possible; group new keys under appropriate namespaces.
- If a locale is missing a translation at review time, translate the English copy rather than leaving it undefined.

# Translation Normalization & Coverage

We use the `i18n-tasks` gem to ensure all translation keys are present, normalized, and up-to-date across all supported locales (en, fr, es, etc.).

## Workflow
- Run `i18n-tasks normalize` to sort and format locale files.
- Run `i18n-tasks missing` to identify missing keys and add them in English first.
- Use `i18n-tasks add-missing` to auto-populate missing keys with English values, then translate as needed.
- Review and improve translation quality regularly.
- All new user-facing strings must be added to locale files and checked with `i18n-tasks` before merging.

## Example Commands
```bash
bin/dc-run i18n-tasks normalize
bin/dc-run i18n-tasks missing
bin/dc-run i18n-tasks add-missing
bin/dc-run i18n-tasks health
```

## CI Note
- The i18n GitHub Action installs dev/test gem groups to make `i18n-tasks` available. Locally, you can mirror CI with `bin/dc-run bin/i18n`, which sets `BUNDLE_WITH=development:test` automatically.

See `.github/instructions/i18n-mobility.instructions.md` for additional translation rules.

# Testing Requirements

## Test-Driven Development (TDD) Approach

### Implementation Plan to Acceptance Criteria Process
1. **Start with confirmed implementation plan** that has passed collaborative review
2. **Create acceptance criteria** using the template in `docs/tdd_acceptance_criteria_template.md`
3. **Transform implementation plan** into specific stakeholder acceptance criteria with the pattern "As a [stakeholder], I want [capability] so that [benefit]"
4. **Generate comprehensive test coverage** for each acceptance criteria before writing implementation code
5. **Follow Red-Green-Refactor cycle** for each acceptance criteria:
   - Write failing tests that validate stakeholder needs (RED)
   - Write minimum code to pass tests (GREEN)
   - Refactor code while maintaining test coverage (REFACTOR)
6. **Validate with stakeholders** after each feature completion

### Acceptance Criteria Generation from Implementation Plans
When responding to a confirmed implementation plan:
1. **Reference the implementation plan** document and confirm collaborative review completion
2. **Identify affected stakeholders** based on the feature scope and functionality
3. **Create acceptance criteria document** using `docs/tdd_acceptance_criteria_template.md`
4. **Define testable behaviors** that deliver the implementation plan's intended outcomes
5. **Structure test coverage matrix** showing which tests validate which acceptance criteria
6. **Implement using TDD cycle** one acceptance criteria at a time

### Stakeholder-Focused Acceptance Criteria
For every implementation plan, create acceptance criteria covering relevant stakeholders:
- **End Users**: Community members needing safety and social features
- **Community Organizers**: Elected leaders managing community moderation and member engagement  
- **Platform Organizers**: Elected staff managing comprehensive platform operations and host community/platform
- **Content Moderators**: Community volunteers reviewing reports and supporting platform safety
- **Additional roles**: Include other stakeholders as relevant to specific features (Support Staff, Legal/Compliance, etc.)

## Mandatory Test Generation
- **Every code change must include RSpec tests** covering the new or modified functionality.
- **Generate factories for new models** using FactoryBot with realistic Faker-generated test data.
- **Test all layers**: models (validations, associations, methods), controllers (actions, authorization), services, mailers, jobs, and view components.
- **JavaScript/Stimulus testing**: Include feature specs that exercise dynamic behaviors like form interactions and AJAX updates.

## Test Environment Requirements
- **Host Platform Configuration**: All controller, request, and feature tests MUST configure the host platform/community before testing.
- **Use `configure_host_platform`**: Call this helper method in a `before` block for any test that makes HTTP requests or tests authentication/authorization.
- **DeviseSessionHelpers**: Include this module and use authentication helpers like `login('user@example.com', 'password')` for authenticated tests.
- **Platform Setup Pattern**:
  ```ruby
  RSpec.describe BetterTogether::SomeController do
    before do
      configure_host_platform  # Creates host platform with community
      login('user@example.com', 'password')  # For authenticated tests
    end
  end
  ```
- **Required for**: Controller specs, request specs, feature specs, and any integration tests that involve routing or authentication.
- **Locale Parameters**: Engine controller tests require locale parameters (e.g., `params: { locale: I18n.default_locale }`) due to routing constraints.

## Test Coverage Standards
- **Models**: Test validations, associations, scopes, instance methods, class methods, and callbacks.
- **Controllers**: Test all actions, authorization policies, parameter handling, and response formats.
- **Mailers**: Test email content, recipients, localization, and delivery configurations.
- **Jobs**: Test job execution, retry behavior, error handling, and side effects.
- **JavaScript**: Test Stimulus controller behavior, form interactions, and dynamic content updates.
- **Integration**: Test complete user workflows and cross-model interactions.
- **Feature Tests**: End-to-end stakeholder workflows validating acceptance criteria.

## TDD Test Types by Stakeholder Need

### End User-Focused Tests
```ruby
# Feature tests validating user experience
RSpec.feature 'User Safety Controls' do
  scenario 'user blocks another user from profile page' do
    # Tests AC: I can block users from their profile page
  end
end
```

### Organizer/Moderator-Focused Tests  
```ruby
# Controller tests validating management capabilities
RSpec.describe BetterTogether::ReportsController do
  context 'when platform organizer processes reports' do
    # Tests AC: I can filter reports by category and status
  end
end
```

### Cross-Stakeholder Integration Tests
```ruby
# Integration tests validating complete workflows
RSpec.describe 'Report Processing Workflow' do
  scenario 'end-user reports content through organizer resolution' do
    # Tests complete stakeholder journey
  end
end
```

## Session Coverage Requirements
When making changes to existing code, generate tests that cover:
- All modified models and their new/changed methods, associations, and validations
- Any new background jobs, mailers, and notification systems
- Controller actions that handle the new functionality
- JavaScript controllers and dynamic form behaviors
- Integration tests for complete user workflows
- Edge cases and error conditions
- **Stakeholder acceptance criteria** for all affected user types

## Test Organization
- Follow the existing RSpec structure and naming conventions.
- Use FactoryBot factories instead of direct model creation.
- Group related tests with descriptive context blocks aligned with acceptance criteria.
- Use shared examples for common stakeholder behavior patterns.
- Mock external dependencies and network calls.
- **Tag tests with stakeholder context** using RSpec metadata.

## Documentation Maintenance

### Stakeholder-Focused Documentation Structure
- **Primary documentation index**: [`docs/table_of_contents.md`](docs/table_of_contents.md) - comprehensive stakeholder-organized guide
- **7 stakeholder groups**: end_users, community_organizers, platform_organizers, developers, support_staff, content_moderators, legal_compliance
- **Specialized sections**: shared/, implementation/, diagrams/, ui/, production/, scripts/, reference/, development/, joatu/, meta/

### Documentation Updates Required
When adding new functionality or systems:
1. **Update table of contents** - Add new documentation files to appropriate stakeholder sections
2. **Follow documentation standards** - Use templates in `implementation/templates/` for consistency
3. **Add diagrams** - Create Mermaid source (.mmd) files in `diagrams/source/` and render with `bin/render_diagrams`
4. **Link diagrams properly** - Follow standard diagram linking pattern (see Diagram Integration Standards below)
5. **Update progress tracking** - Run `docs/scripts/update_progress.sh` to update completion metrics
6. **Validate documentation** - Run `docs/scripts/validate_documentation_tooling.sh` to ensure integrity

### Diagram Integration Standards
- **Include diagrams in system documentation**: Every system doc must link to its related diagrams
- **GitHub-compatible rendering**: Include `.mmd` source content directly in documentation for inline GitHub rendering
- **Multiple format links**: Provide links to Mermaid source, PNG (high-res), and SVG (vector) versions
- **Standard pattern**:
  ```markdown
  ## Process Flow Diagram
  
  ```mermaid
  <!-- Embed .mmd content here for GitHub inline rendering -->
  ```
  
  **Diagram Files:**
  - 📊 [Mermaid Source](../diagrams/source/system_name_flow.mmd) - Editable source
  - 🖼️ [PNG Export](../diagrams/exports/png/system_name_flow.png) - High-resolution image  
  - 🎯 [SVG Export](../diagrams/exports/svg/system_name_flow.svg) - Vector graphics
  ```
- **Update existing documentation**: Retrospectively add diagram links to existing system documentation

### Documentation Script Usage
- **Progress updates**: `docs/scripts/update_progress.sh [system_name] [start|complete]`
- **Diagram rendering**: `bin/render_diagrams [--force]` - Generate PNG/SVG from Mermaid sources
- **Validation**: `docs/scripts/validate_documentation_tooling.sh` - Check documentation system health
- **Stakeholder structure**: `docs/scripts/create_stakeholder_structure.sh` - Maintain directory organization

### System Documentation Requirements
Each major system must include:
- Comprehensive technical documentation (minimum 200 lines)
- Process flow diagram with Mermaid source + rendered exports
- Database schema with relationships and field descriptions  
- Implementation examples and configuration guides
- Performance considerations and caching strategies
- Security implications and access controls
- API endpoints with request/response examples
- Monitoring tools and troubleshooting procedures

## Testing Architecture Consistency Lessons Learned

### Critical Testing Pattern: Request Specs vs Controller Specs
- **Project Standard**: All tests use request specs (`type: :request`) for consistency with Rails engine routing
- **Exception Handling**: Controller specs (`type: :controller`) require special URL helper configuration in Rails engines
- **Why This Matters**: Request specs handle Rails engine routing automatically through the full HTTP stack, while controller specs test in isolation and need explicit configuration
- **Debugging Indicator**: If you see `default_url_options` errors only in one spec while others pass, check if it's a controller spec in a request spec codebase

### Rails Engine URL Helper Configuration
- **Problem**: Controller specs in Rails engines throw `default_url_options` errors that request specs don't encounter
- **Root Cause**: Engines need special URL helper setup for controller specs but not request specs
- **Solution Patterns**:
  ```ruby
  # For controller spec assertions, use pattern matching instead of path helpers:
  expect(response.location).to include('/person_blocks') # Good
  expect(response).to redirect_to(person_blocks_path) # Problematic in controller specs
  
  # Ensure consistent route naming throughout:
  # Controller: person_blocks_path (not blocks_path)
  # Views: <%= link_to "Block", better_together.person_blocks_path %>
  # Tests: params path should match controller actions
  ```

### Route Naming Convention Enforcement
- **Pattern**: Engine routes follow full resource naming: `better_together.resource_name_path`
- **Common Error**: Using shortened path names (`blocks_path`) instead of full names (`person_blocks_path`)
- **Consistency Check**: Views, controllers, and tests must all use the same complete path helper names
- **Verification**: Check all three layers when debugging routing issues

### Factory and Association Dependencies
- **Requirement**: Every Better Together model needs a corresponding FactoryBot factory
- **Naming Convention**: Factory names follow `better_together_model_name` pattern with aliases
- **Association Setup**: Factories must properly handle engine namespace associations
- **Missing Factory Indicator**: Tests failing on association creation often indicate missing factories

### Test Environment Configuration Enforcement
- **Critical Setup**: `configure_host_platform` must be called before any controller/request/feature tests
- **Why Required**: Better Together engine needs host platform setup for authentication and authorization
- **Pattern Recognition**: Tests failing with authentication/authorization errors often need this setup
- **Documentation Reference**: This pattern is well-documented but bears reinforcement

### Architecture Consistency Principles
- **Consistency Is Key**: When one component (PersonBlocksController) differs from project patterns, it requires special handling
- **Pattern Detection**: Single anomalies (one controller spec among many request specs) signal architectural inconsistencies
- **Prevention**: New tests should follow the established pattern (request specs) unless there's a compelling reason for exceptions
- **Documentation**: When exceptions are necessary, document why they exist and how to handle their special requirements

### Testing Strategy Recommendations
- **Default Choice**: Use request specs for new controller tests to maintain consistency
- **Engine Compatibility**: Request specs handle Rails engine complexity automatically
- **Special Cases**: If controller specs are needed, prepare for URL helper configuration complexity
- **Debugging Approach**: When testing errors occur in only one spec, compare its type and setup to working specs

## Docker Environment Usage
- **All database-dependent commands must use `bin/dc-run`**: This includes tests, generators, and any command that connects to PostgreSQL, Redis, or Elasticsearch
- **Dummy app commands use `bin/dc-run-dummy`**: For Rails commands that need the dummy app context (console, migrations specific to dummy app)
- **Examples of commands requiring `bin/dc-run`**:
  - Tests: `bin/dc-run bundle exec rspec`
  - Generators: `bin/dc-run rails generate model User`
  - Brakeman: `bin/dc-run bundle exec brakeman`
  - RuboCop: `bin/dc-run bundle exec rubocop`
- **Examples of commands requiring `bin/dc-run-dummy`**:
  - Rails console: `bin/dc-run-dummy rails console`
  - Dummy app migrations: `bin/dc-run-dummy rails db:migrate`
  - Dummy app database operations: `bin/dc-run-dummy rails db:seed`
- **Commands that don't require bin/dc-run**: File operations, documentation generation (unless database access needed), static analysis tools that don't connect to services
