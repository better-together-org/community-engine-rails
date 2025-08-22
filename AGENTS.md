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
- Databases:
  - development: `community_engine_development`
  - test: `community_engine_test`
- Use `DATABASE_URL` to connect (overrides fallback host in `config/database.yml`).

## Commands
- **Tests:** `bin/ci`
  (Equivalent: `cd spec/dummy && bundle exec rspec`)
- **Lint:** `bundle exec rubocop`
- **Security:** `bundle exec brakeman --quiet --no-pager` and `bundle exec bundler-audit --update`
- **Style:** `bin/codex_style_guard`
- **I18n:** `bin/i18n [normalize|check|health|all]` (runs normalize + missing + interpolation checks by default)

## Security Requirements
## Security Requirements
- **Run Brakeman before generating code**: `bundle exec brakeman --quiet --no-pager` 
- **Fix high-confidence vulnerabilities immediately** - never ignore security warnings with "High" confidence
- **Review and address medium-confidence warnings** that are security-relevant
- **Safe coding practices when generating code:**
  - Never use `constantize`, `safe_constantize`, or `eval` on user input
  - Use allow-lists for dynamic class resolution (see `joatu_source_class` pattern)
  - Sanitize and validate all user inputs
  - Use strong parameters in controllers
  - Implement proper authorization checks (Pundit policies)
- **For reflection-based features**: Create concerns with `included_in_models` class methods for safe dynamic class resolution
- **Post-generation security check**: Run `bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after major code changes

## Conventions
- Make incremental changes with passing tests.
- **Security first**: Run `bundle exec brakeman --quiet --no-pager` before committing code changes.
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
  - For model/association changes: update Mermaid diagrams (e.g., `docs/*_diagram.mmd` or add a new one alongside related docs).
- Keep diagrams in Mermaid (`.mmd`) and render PNGs for convenience.
  - Preferred: run `bin/render_diagrams` to regenerate images for all `docs/*.mmd` files.
  - Fallback: `npx -y @mermaid-js/mermaid-cli -i docs/your_diagram.mmd -o docs/your_diagram.png`.
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
i18n-tasks normalize
i18n-tasks missing
i18n-tasks add-missing
i18n-tasks health
```

## CI Note
- The i18n GitHub Action installs dev/test gem groups to make `i18n-tasks` available. Locally, you can mirror CI with `bin/i18n`, which sets `BUNDLE_WITH=development:test` automatically.

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
