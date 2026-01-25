# AGENTS.md

Instructions for GitHub Copilot and other automated contributors working in this repository.

## Project
- Ruby: 3.4.4 (installed via rbenv in setup)
- Rails: 7.2
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

## Debugging Guidelines
- **Never use Rails console or runner for debugging** - These commands don't align with our test-driven development approach
- **Use comprehensive test suites instead**: Write detailed tests to understand and verify system behavior
- **Debug through tests**: Create specific test scenarios to reproduce and validate fixes for issues
- **Use log analysis**: Examine Rails logs, test output, and error messages for debugging information
- **Add temporary debugging assertions in tests**: Use `expect()` statements to verify intermediate state in tests
- **Use RSpec debugging tools**: Use `--format documentation` for detailed test output, `fit` for focused testing
- **Trace through code by reading files**: Use file reading and grep search to understand code paths
- **Add debug output in application code temporarily** if needed, but remove before committing
- **Validate fixes through test success**: Confirm that issues are resolved by having tests pass

## RSpec Stubbing Guidelines
- **Avoid `allow_any_instance_of`**: It creates global stubs that can leak across examples and cause flaky tests.
- **Stub specific instances**: Use `allow(platform).to receive(:update!).and_return(true)` in the example that needs it.
- **Prefer `build_stubbed` for nil/timezone scenarios**: Use stubbed instances instead of mutating database constraints in setup.

## Commands

### Test Execution Guidelines (CRITICAL)
- **NEVER run the full test suite (`bin/dc-run bin/ci` or `bin/dc-run bundle exec prspec spec`) until ALL targeted tests pass individually**
- **Full suite takes 13-18 minutes** - running it prematurely wastes time and resources (even with parallel execution)
- **Always verify specific tests first**: Run individual test files or line numbers to confirm fixes work
- **Test execution workflow**:
  1. Identify failing tests from error report
  2. Run each failing test individually with `prspec` to reproduce the issue
  3. Make fixes and verify each test passes in isolation with `prspec`
  4. Run all previously failing tests together with `prspec` to verify no interactions
  5. ONLY THEN run the full test suite with `prspec spec` (via `bin/ci`) to verify no regressions

### Test Commands
- **Full Test Suite (USE SPARINGLY):** `bin/dc-run bin/ci`
  - Uses `prspec` (parallel_rspec) for faster execution via parallelization
  - Equivalent: `bin/dc-run bundle exec prspec spec --format documentation`
  - Alternative (slower, sequential): `bin/dc-run bash -c "cd spec/dummy && bundle exec rspec"`
- **Running specific tests (PREFER THIS):** 
  - **Prefer `prspec`** for all test runs - it's faster than plain `rspec`
  - Single spec file: `bin/dc-run bundle exec prspec spec/path/to/file_spec.rb`
  - Specific line: `bin/dc-run bundle exec prspec spec/path/to/file_spec.rb:123`
  - Multiple files: `bin/dc-run bundle exec prspec spec/file1_spec.rb spec/file2_spec.rb`
  - Multiple specific lines: `bin/dc-run bundle exec prspec spec/file1_spec.rb:123 spec/file2_spec.rb:456`
  - Fallback (if prspec unavailable): Use `rspec` with same arguments
  - **Important**: Neither tool supports hyphenated line numbers (e.g., `spec/file_spec.rb:123-456` is INVALID)
  - **Do NOT use `-v` flag**: The `-v` flag displays version information, NOT verbose output. Use `--format documentation` for detailed test descriptions.
  - **Note**: `prspec` always requires a spec path argument (file, directory, or line number)
- **Rails Console:** `bin/dc-run-dummy rails console` (for administrative tasks only - NOT for debugging. Use comprehensive tests for debugging instead)
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
  - Define model-level permitted attributes: prefer a class method `self.permitted_attributes` on models that returns the permitted attribute list (including nested attribute structures). Controllers should call `Model.permitted_attributes` to build permit lists instead of hard-coding them. When composing nested attributes, reference other models' `permitted_attributes` (for example: `Conversation.permitted_attributes` may include `{ messages_attributes: Message.permitted_attributes }`).
  - Implement proper authorization checks (Pundit policies)
- **For reflection-based features**: Create concerns with `included_in_models` class methods for safe dynamic class resolution
- **Post-generation security check**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager -c UnsafeReflection,SQL,CrossSiteScripting` after major code changes

## Conventions
- Make incremental changes with passing tests.
- **Security first**: Run `bin/dc-run bundle exec brakeman --quiet --no-pager` before committing code changes.
- **Test every change**: Generate RSpec tests for all code modifications, including models, controllers, mailers, jobs, and JavaScript.
- **Test coverage requirements**: All new features, bug fixes, and refactors must include comprehensive test coverage.
- **Test execution**: Use `prspec` for all test runs (faster than plain `rspec`); use `prspec spec` (via `bin/ci`) for full suite.
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

## Database Query Standards
- **Prefer Active Record associations and standard query methods** for simple queries
  - Use `.joins(:association)` when associations are defined
  - Use `.includes()` for eager loading to prevent N+1 queries
  - Use `.where()`, `.order()`, `.group()` for standard filtering and sorting
- **Use Arel for complex queries** when raw SQL would otherwise be needed
  - Never use raw SQL strings in `.joins()`, `.where()`, or similar methods
  - Use Arel table objects for cross-table queries without defined associations
  - Example pattern:
    ```ruby
    # Good: Using Arel for complex join
    users = User.arel_table
    posts = Post.arel_table
    User.joins(users.join(posts).on(users[:id].eq(posts[:user_id])).join_sources)
    
    # Bad: Raw SQL string
    User.joins('INNER JOIN posts ON users.id = posts.user_id')
    ```
- **When to use Arel**:
  - Complex joins across tables without associations
  - Subqueries and CTEs
  - Custom SQL functions and operations
  - Dynamic query building with conditional logic
- **Benefits of Arel**:
  - Database-agnostic (works across PostgreSQL, MySQL, SQLite)
  - SQL injection protection built-in
  - Type-safe and refactorable
  - Better IDE support and autocomplete
- **Arel Resources**:
  - Use `Model.arel_table` to get the Arel table object
  - Use `.eq()`, `.not_eq()`, `.gt()`, `.lt()` for comparisons
  - Use `.and()`, `.or()` for logical operations
  - Use `.join()` with `.on()` for complex joins

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

### Passing Translations to Stimulus Controllers
When Stimulus controllers need access to translated strings, pass them via data attributes on the controller element:

**Rails View Pattern:**
```erb
<%= form_with(model: resource, data: { 
  controller: "better-together--my-controller",
  'better-together--my-controller-error-message-text': t('my_scope.error_message'),
  'better-together--my-controller-success-message-text': t('my_scope.success_message')
}) do |form| %>
```

**JavaScript Access Pattern:**
```javascript
// Stimulus controller: better_together/my_controller.js
getTranslation(key) {
  const fallbacks = {
    'error_message': 'An error occurred',
    'success_message': 'Success!'
  }
  
  // Convert snake_case key to dataset format with hyphens
  // e.g., 'error_message' -> 'betterTogether-MyControllerErrorMessageText'
  const words = key.split('_')
  const capitalizedWords = words.map(word => word.charAt(0).toUpperCase() + word.slice(1))
  const dataKey = `betterTogether-MyController${capitalizedWords.join('')}Text`
  
  return this.element.dataset[dataKey] || fallbacks[key] || key
}
```

**Key Points:**
- Data attribute names use controller name with hyphens: `data-better-together--my-controller-key-text`
- In JavaScript `dataset`, hyphens remain between namespace parts: `betterTogether-MyController...`
- The rest of the key is camelCase: `ErrorMessageText`
- Always provide fallback English strings in the JavaScript for development/testing
- Add all translation keys to locale files for all supported languages (en, es, fr, uk)

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

### SlimSelect Feature Spec Pattern
When testing forms with SlimSelect-enhanced select dropdowns, use a layered waiting strategy to prevent flaky tests:

**Key Principle**: Don't rely on SlimSelect's generated DOM alone - wait for the underlying `<select>` element first.

**Required Pattern**:
```ruby
# 1. Wait for the underlying select element with visible: :all (SlimSelect hides it)
expect(page).to have_css('select[name="form[field_name][]"]', visible: :all, wait: 10)

# 2. Then wait for SlimSelect Stimulus controller to initialize its wrapper
expect(page).to have_css('.ss-main', wait: 5)

# 3. Now interact with SlimSelect UI
select_wrapper = find('.ss-main', match: :first)
select_wrapper.click
```

**Why This Works**:
- **Layered waiting** ensures each initialization step completes before the next
- **`visible: :all`** finds hidden elements (SlimSelect hides the original `<select>`)
- **Explicit waits** for underlying element → SlimSelect wrapper → interaction prevents race conditions
- **Matches proven pattern** from timezone selector accessibility tests

**Common Mistakes**:
- ❌ Waiting only for `.ss-main` (Stimulus might not have connected yet)
- ❌ Using default `visible` setting (won't find hidden select element)
- ❌ Not waiting for underlying select before checking for SlimSelect wrapper

**Example** (from `spec/support/better_together/conversation_helpers.rb`):
```ruby
def create_conversation(participants, options = {})
  visit new_conversation_path(locale: I18n.default_locale)

  # Wait for underlying select (hidden but in DOM)
  expect(page).to have_css('select[name="conversation[participant_ids][]"]', visible: :all, wait: 10)
  
  # Wait for SlimSelect initialization
  expect(page).to have_css('.ss-main', wait: 5)
  
  # Interact with UI
  find('.ss-main', match: :first).click
  # ... select options
end
```

## HTML Assertion Helpers for Testing HTML Content

### For Request Specs (testing controllers/responses)

When testing HTML responses with factory-generated content (names, titles, etc.) that may contain apostrophes or special characters, **ALWAYS use HTML assertion helpers** instead of direct `response.body` checks to prevent flaky tests from HTML entity escaping.

When testing HTML responses with factory-generated content (names, titles, etc.) that may contain apostrophes or special characters, use the HTML assertion helpers instead of direct `response.body` checks.

**The Problem:**
```ruby
# ❌ FAILS - HTML escaping breaks string comparison
person = create(:person, name: "O'Brien")
get person_path(person)
expect(response.body).to include(person.name)  
# Fails: HTML has "O&#39;Brien" but assertion checks for "O'Brien"
```

**The Solution:**
```ruby
# ✅ WORKS - Parse HTML and decode entities
expect_html_content(person.name)  # Handles escaping automatically
```

**Available Helpers:**
- `expect_html_content(text)` - Check if HTML contains text (handles escaping)
- `expect_no_html_content(text)` - Check if HTML does NOT contain text
- `expect_html_contents(*texts)` - Check multiple texts at once
- `response_text` - Get plain text from HTML (entities decoded)
- `parsed_response` - Get Nokogiri document for custom queries
- `expect_element_content(selector, text)` - Check specific element
- `expect_element_count(selector, count)` - Verify element count
- `element_texts(selector)` - Get array of text from matching elements

**When to Use:**
- ✅ Always for factory-generated names, titles, descriptions
- ✅ When testing with data containing apostrophes, quotes, or special characters
- ✅ Request specs checking text content in HTML responses
- ❌ Don't change HTML structure checks: `expect(response.body).to include('data-controller=')`
- ❌ Don't use in feature specs - use Capybara matchers instead

**Quick Reference:** [`docs/reference/html_assertion_helpers_reference.md`](docs/reference/html_assertion_helpers_reference.md)

**Examples:**
```ruby
# Basic usage
expect_html_content(person.name)

# Multiple checks
expect_html_contents(member1.name, member2.name, member3.name)

# Element-specific
expect_element_content('.member-name', person.name)

# Direct text access for custom matchers
expect(response_text).to match(/O'Brien/)
```

### For Mailer Specs (testing email content)

Mailer specs have the same HTML escaping issues. **ALWAYS use mailer HTML helpers** when checking email content.

**The Problem:**
```ruby
# ❌ FLAKY - Fails when event.name contains apostrophes
let(:mail) { EventMailer.with(event: event).reminder }

it 'includes event name' do
  expect(mail.body.encoded).to include(event.name)
  # Fails: HTML has "O&#39;Brien" but assertion checks "O'Brien"
end
```

**The Solution:**
```ruby
# ✅ ROBUST - Parse HTML and decode entities
it 'includes event name' do
  expect_mail_html_content(mail, event.name)
end
```

**Available Helpers:**
- `expect_mail_html_content(mail, text)` - Check if mail HTML contains text
- `expect_no_mail_html_content(mail, text)` - Check if mail HTML does NOT contain text
- `expect_mail_html_contents(mail, *texts)` - Check multiple texts at once
- `mail_text(mail)` - Get plain text from HTML (entities decoded)
- `parsed_mail_body(mail)` - Get Nokogiri document for custom queries
- `expect_mail_element_content(mail, selector, text)` - Check specific element
- `expect_mail_element_count(mail, selector, count)` - Verify element count
- `mail_element_texts(mail, selector)` - Get array of text from matching elements

**When to Use:**
- ✅ Always for factory-generated names, titles, descriptions in mailers
- ✅ When testing with Faker-generated data (may contain apostrophes)
- ✅ Mailer specs checking text content in HTML emails
- ❌ Don't change HTML structure checks: `expect(mail.body.encoded).to include('data-controller=')`

**Quick Reference:** [`docs/reference/mailer_html_helpers_reference.md`](docs/reference/mailer_html_helpers_reference.md)

**Examples:**
```ruby
# Basic usage
expect_mail_html_content(mail, event.name)

# Multiple checks
expect_mail_html_contents(mail, event.name, location.name, person.name)

# Element-specific
expect_mail_element_content(mail, 'h1', event.name)

# Direct text access
expect(mail_text(mail)).to include("O'Brien")
```

### Critical Rule: Never Check Factory Content Without HTML Helpers

Factory-generated content (via Faker) may randomly include special characters that get HTML-encoded:
- Apostrophes: `'` → `&#39;` or `&apos;`
- Quotes: `"` → `&#34;` or `&quot;`
- Ampersands: `&` → `&amp;`

**ALWAYS:**
- ✅ Use `expect_html_content()` for request specs
- ✅ Use `expect_mail_html_content()` for mailer specs
- ✅ Use these helpers for ANY factory-generated text (names, titles, descriptions)

**NEVER:**
- ❌ `expect(response.body).to include(factory_model.name)`
- ❌ `expect(mail.body.encoded).to include(factory_model.title)`
- ❌ Direct string matching on HTML content with factory data

## Test Coverage Standards
- **Models**: Test validations, associations, scopes, instance methods, class methods, and callbacks.
- **Controllers**: Test all actions, authorization policies, parameter handling, and response formats.
- **Mailers**: Test email content, recipients, localization, and delivery configurations.
- **Jobs**: Test job execution, retry behavior, error handling, and side effects.
- **JavaScript**: Test Stimulus controller behavior, form interactions, and dynamic content updates.
- **Integration**: Test complete user workflows and cross-model interactions.
- **Feature Tests**: End-to-end stakeholder workflows validating acceptance criteria.
- **Accessibility**: All UI elements must pass WCAG 2.1 AA standards (see Accessibility Testing Requirements below).

## Accessibility Testing Requirements

### WCAG 2.1 AA Compliance (MANDATORY)
All user-facing HTML elements generated or modified in tests MUST pass WCAG 2.1 AA accessibility standards using axe-core automated testing.

### When to Add Accessibility Tests
- **Feature specs with `:js` metadata**: Any test that renders HTML with interactive elements
- **New form fields**: All input, select, textarea, and custom form controls
- **Dynamic content**: Content updated via Stimulus controllers or Turbo frames
- **Interactive widgets**: Dropdowns, modals, tabs, accordions, date pickers, etc.
- **Navigation elements**: Menus, breadcrumbs, pagination, search interfaces
- **Content updates**: Any element that changes state or displays user feedback

### Infrastructure Setup
- **axe-core gems**: Already installed (axe-core-capybara, axe-core-rspec, axe-core-selenium)
- **Configuration**: `spec/support/axe.rb` configures WCAG 2.1 AA testing
- **Chrome driver**: JavaScript injection for axe-core scanner enabled

### Required Accessibility Patterns

#### Form Field Requirements
All form inputs MUST have accessible labels using ONE of these methods:

1. **Explicit label with `for` attribute** (preferred for visible labels):
   ```ruby
   <%= form.label :field_name, t('label.key'), class: 'form-label' %>
   <%= form.text_field :field_name, id: 'explicit_id', class: 'form-control' %>
   ```

2. **aria-label attribute** (for fields where visible labels aren't appropriate):
   ```ruby
   <%= form.text_field :field_name, 
       'aria-label': t('label.key'),
       class: 'form-control' %>
   ```

3. **Implicit label wrapping** (for simple cases):
   ```erb
   <label class="form-label">
     <%= t('label.key') %>
     <%= form.text_field :field_name %>
   </label>
   ```

#### Test Pattern for Accessibility
```ruby
RSpec.describe 'Feature Name', type: :feature, js: true, accessibility: true do
  it 'passes WCAG 2.1 AA accessibility checks' do
    visit some_path
    
    # Verify interactive elements are present
    expect(page).to have_css('#target-element')
    
    # Run axe-core accessibility scanner
    expect(page).to be_axe_clean
      .within('#container-id')           # Scope to relevant section
      .excluding('.pre-existing-issues')  # Exclude known issues if necessary
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
```

### Common Accessibility Violations to Prevent

1. **Missing Form Labels** (Critical)
   - Ensure every input has an associated label or aria-label
   - Use `id` attributes on inputs and matching `for` on labels
   - Add aria-label for icon-only buttons

2. **Insufficient Color Contrast** (Serious)
   - Text must have 4.5:1 contrast ratio for normal text
   - Large text (18pt+ or 14pt+ bold) needs 3:1 ratio
   - Use Bootstrap's standard color classes for compliance

3. **Missing ARIA Roles** (Moderate)
   - Interactive elements need proper role attributes
   - Search inputs should have `role="searchbox"`
   - Custom controls need appropriate ARIA states

4. **Keyboard Navigation** (Critical)
   - All interactive elements must be keyboard accessible
   - Tab order must be logical and complete
   - Focus indicators must be visible

5. **Missing Alt Text** (Critical)
   - All images need descriptive alt attributes
   - Decorative images should have `alt=""`
   - Icon fonts need aria-label or sr-only text

### Metadata Tags for Accessibility Tests
```ruby
# Full accessibility test with WCAG 2.1 AA validation
RSpec.describe 'Form', type: :feature, js: true, accessibility: true do
  # Tests here
end

# Disable retries for accessibility tests to prevent database pollution
RSpec.describe 'Form', type: :feature, js: true, accessibility: true, retry: 0 do
  # Tests here
end
```

### Accessibility Validation Workflow
1. **Before implementation**: Review designs for accessibility issues
2. **During development**: Add accessibility tests alongside feature tests
3. **After implementation**: Run axe-core scans to verify compliance
4. **Fix violations**: Address all critical and serious violations immediately
5. **Document exceptions**: If violations can't be fixed, document why and create tracking issue

### Resources
- **axe-core documentation**: https://github.com/dequelabs/axe-core
- **WCAG 2.1 Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **Deque University**: https://dequeuniversity.com/rules/axe/4.11/
- **Project accessibility docs**: `docs/development/accessibility_testing.md`

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

## Timezone Management Best Practices

> **Comprehensive Guide**: See [docs/development/timezone_handling_strategy.md](docs/development/timezone_handling_strategy.md) for complete documentation.

### Core Principles
- **Store UTC**: All `datetime` columns store times in UTC; Rails handles conversion automatically
- **IANA Identifiers Only**: Use `America/New_York`, NOT Rails timezone names like "Eastern Time (US & Canada)"
- **Validate with TZInfo**: `validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }`
- **Convert for Display**: Use `.in_time_zone()` to convert UTC to local times in views
- **Per-Request Context**: `around_action :set_time_zone` sets timezone for entire request

### Form Helpers
- **Always use** `iana_time_zone_select` helper for timezone selection forms
- **Never use** Rails' `time_zone_select` (it uses Rails timezone names incompatible with IANA validation)
- Example: `<%= iana_time_zone_select(f, :timezone, selected: @event.timezone) %>`

### Common Pitfalls to Avoid
```ruby
# ❌ WRONG - Rails timezone name
event.timezone = "Eastern Time (US & Canada)"

# ✅ CORRECT - IANA identifier  
event.timezone = "America/New_York"

# ❌ WRONG - Storing local time
event.starts_at = Time.zone.now  # if Time.zone is user's timezone

# ✅ CORRECT - Store UTC, convert for display
event.starts_at = Time.current  # Always UTC
display_time = event.starts_at.in_time_zone(user.time_zone)

# ❌ WRONG - Global timezone change
Time.zone = user.time_zone

# ✅ CORRECT - Scoped timezone context
Time.use_zone(user.time_zone) { formatted_time = event.starts_at.strftime('%I:%M %p') }
```

### Testing Requirements
- **Explicit timezone in factories**: `factory :event do timezone { 'UTC' } end`
- **Match timezone in tests**: If event has `timezone: 'UTC'`, use `Time.zone = 'UTC'` in test
- **Avoid timezone mismatches**: Ensure factory timezone matches test expectations

### Architecture Components
- **TimezoneAttributeAliasing concern**: Provides backward compatibility between `timezone` and `time_zone`
- **Request-level handling**: `ApplicationController#set_time_zone` with user → platform → app config → UTC hierarchy
- **Model validation**: All timezone attributes validated against `TZInfo::Timezone.all_identifiers`
- **Form helpers**: `iana_time_zone_select` for IANA identifier selection
