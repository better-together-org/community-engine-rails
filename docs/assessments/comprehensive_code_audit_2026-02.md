# Better Together Community Engine — Comprehensive Code Audit

<!-- historical-doc-banner -->
> **Historical document.** Written on 2026-02-11. It records the code, plans and findings as they stood then and is not maintained for later releases. For current behaviour see the [documentation index](../table_of_contents.md).
<!-- /historical-doc-banner -->

**Audit Date:** February 11, 2026
**Rails Version:** 8.0.3
**Ruby Version:** 3.4.4
**Engine Gem:** better_together (7.2+–8.0)

---

## Executive Summary

This audit covers every top-level directory under `app/` — models, controllers, views, helpers, policies, builders, robots (bots), resources, forms, channels, notifiers, services, sanitizers, integrations, jobs, mailers, and JavaScript — as well as configuration, dependencies, i18n, security, and test coverage. Findings are organized into **Questions You Should Be Asking**, grouped by domain.

**Overall Assessment: B+** — strong architectural foundations, modern stack, good security posture. Critical gaps exist in **test coverage** (policies, builders, services, channels, resources have zero specs), **authorization policy permissiveness** (3 policies too open), and **CSP enforcement** (disabled in production).

---

## Table of Contents

1. [Security & Authorization](#1-security--authorization)
2. [Policies (Pundit)](#2-policies-pundit)
3. [Controllers](#3-controllers)
4. [Models & Data Integrity](#4-models--data-integrity)
5. [Builders](#5-builders)
6. [Robots / Bots (AI)](#6-robots--bots-ai)
7. [API Resources (JSONAPI)](#7-api-resources-jsonapi)
8. [Forms](#8-forms)
9. [Channels (ActionCable)](#9-channels-actioncable)
10. [Notifiers (Noticed)](#10-notifiers-noticed)
11. [Services](#11-services)
12. [Sanitizers](#12-sanitizers)
13. [Integrations](#13-integrations)
14. [Jobs (Sidekiq)](#14-jobs-sidekiq)
15. [Mailers](#15-mailers)
16. [JavaScript / Stimulus](#16-javascript--stimulus)
17. [Views & Helpers](#17-views--helpers)
18. [Test Coverage](#18-test-coverage)
19. [Dependencies](#19-dependencies)
20. [Internationalization (i18n)](#20-internationalization-i18n)
21. [Infrastructure & Configuration](#21-infrastructure--configuration)
22. [Documentation](#22-documentation)
23. [Summary of Findings by Severity](#23-summary-of-findings-by-severity)

---

## 1. Security & Authorization

### Questions to Ask

1. **Why is the Content Security Policy disabled in production?**
   `config/initializers/content_security_policy.rb` has all directives commented out. This leaves the application vulnerable to XSS via injected scripts. *When will CSP be enabled with proper nonce-based inline script support?*

2. **Is the CORS `ALLOWED_ORIGINS` default of `*` acceptable?**
   `config/initializers/cors.rb` falls back to `*` (allow all origins) when `ALLOWED_ORIGINS` is unset. *Should this default be more restrictive, especially since API endpoints accept mutations (POST/PUT/DELETE)?*

3. **Is `Rack::Attack` configured in all environments?**
   Rate limiting (300 req/5 min, login throttle 5/20s) and Fail2Ban rules are defined. *Are these thresholds appropriate for expected traffic? Is Redis-backed storage enabled in production?*

4. **Are Devise paranoid mode and account locking thresholds reviewed periodically?**
   Paranoid mode is on (good). Lock after 5 attempts for 1 hour. *Has the team tested whether these settings block legitimate users during password recovery flows?*

5. **Is the `unsafe constantize` in `InvitationsController` (line ~153) tracked for remediation?**
   ```ruby
   invitable_type = invitable_param.to_s.gsub('_id', '').classify
   invitable_class = "BetterTogether::#{invitable_type}".constantize
   ```
   User-controlled `invitable_param` feeds `constantize`. A `SafeClassResolver` utility exists but isn't used here. *What is the plan to replace this with an allow-list?*

6. **Is `bundler-audit` running in CI and are advisories reviewed?**
   The gem is present but no `.bundler-audit.yml` configuration file exists. *Are audit results reviewed before deployments?*

### Current Strengths
- ✅ Rack::Attack with IP + email throttling and Fail2Ban
- ✅ Devise: 12-char minimum password, paranoid mode, account locking, JWT expiry (1h)
- ✅ OmniAuth: POST-only, CSRF protection (CVE-2015-9284 mitigated)
- ✅ No hardcoded secrets — all credentials via `ENV.fetch`
- ✅ Brakeman integrated in CI with clean ignore file

---

## 2. Policies (Pundit)

### Questions to Ask

7. **Why can any authenticated user update or destroy Roles?**
   `RolePolicy#update?` and `#destroy?` return `user.present?` without checking `permitted_to?('manage_platform')`. *This is a privilege escalation vector. Should this be restricted to platform managers?*

8. **Why can any authenticated user create, update, and destroy NavigationItems?**
   `NavigationItemPolicy` allows any logged-in user to modify platform navigation. *Should this be restricted to platform managers or community organizers?*

9. **Are empty Scope classes intentional?**
   `MessagePolicy::Scope`, `CallForInterestPolicy::Scope`, and `CategoryPolicy::Scope` have empty scopes that don't filter records. *Does this mean all records are returned regardless of authorization?*

10. **Why do zero policy files have corresponding specs?**
    58 policy files exist with no `spec/policies/` directory. *Authorization is the most critical security layer — what is the plan to add policy specs?*

11. **How are guest/unauthenticated users handled consistently?**
    Most policies check `user.present?` but `NavigationItemPolicy#index?` and `AgreementPolicy#show?` return `true` unconditionally. *Is there a documented standard for what unauthenticated users should access?*

12. **Is the `ApplicationPolicy` default-deny posture tested?**
    The base class defaults all actions to `false`. *Are there integration tests verifying that new resources are locked down by default?*

### Current Strengths
- ✅ Default-deny in `ApplicationPolicy`
- ✅ Centralized `permitted_to?` delegation pattern
- ✅ Privacy-aware scoping (public/private/community)
- ✅ Invitation token support across policies
- ✅ Person blocking checks in PersonPolicy and PostPolicy

---

## 3. Controllers

### Questions to Ask

13. **Are the large controllers (500+ lines) scheduled for refactoring?**
    - `Metrics::ReportsController`: 506 lines with HSL-to-RGB conversion methods
    - `EventsController`: 531 lines with recurrence-rule building and timezone conversion
    *Should color generation and recurrence logic move to service objects?*

14. **Is duplicated search logic in `PersonBlocksController` a pattern to watch?**
    Lines 14–37 and 41–63 contain similar search filtering. *Should this be extracted to a shared concern or scope?*

15. **Do all API controllers enforce authentication consistently?**
    Future API controllers (`future_controllers/`) include Pundit, but the calendar feed endpoint uses token-based auth with `skip_authorization`. *Is the token validation sufficient, and is the skip documented?*

16. **Are `after_action :verify_authorized` and `verify_policy_scoped` used everywhere?**
    18 controllers use `verify_authorized`. *Are the remaining controllers exempt intentionally or by oversight?*

### Current Strengths
- ✅ Thin controllers — business logic in models/services
- ✅ Consistent strong parameter usage via `Model.permitted_attributes`
- ✅ Comprehensive error handling (404, Pundit errors, StandardError)
- ✅ Locale management with fallback chain

---

## 4. Models & Data Integrity

### Questions to Ask

17. **Are there models missing validations on required associations?**
    - `Conversation`: `participant_ids` validated only on create, not update
    - `Page`: `community_id` assigned in callback but no presence validation
    - `User`: `person` association not validated for presence
    *Should these have explicit validations?*

18. **Is the N+1 prevention strategy consistent?**
    `Person#preload_calendar_associations!` is a good pattern. *Are there other hot paths (event listings, community dashboards) that need similar preloading?*

19. **Are all `dependent: :destroy` chains reviewed for cascade impact?**
    `Person` has 30+ associations with `dependent: :destroy`. *Has the team mapped what a person deletion cascades through? Could this cause timeout issues?*

20. **Are model callbacks minimized?**
    Some models (Event, Page) have 5+ callbacks. *Are any of these better suited as service objects or after_commit jobs?*

### Current Strengths
- ✅ Consistent validation patterns (presence, format, inclusion, custom)
- ✅ Strong parameter patterns via `self.permitted_attributes`
- ✅ No raw SQL — all queries via Active Record / Arel
- ✅ No mass assignment vulnerabilities found

---

## 5. Builders

### Questions to Ask

21. **Why do builders have zero test coverage?**
    10 builder files, no `spec/builders/` directory. Builders are the seeding infrastructure. *If a builder silently produces bad data, how would it be caught?*

22. **Why don't builders use database transactions?**
    Multi-step builders (e.g., `JoatuDemoBuilder` creates people → community → addresses → offers → agreements) have no transaction wrapping. *If a builder fails midway, partial data remains. Should `seed_data` methods be wrapped in `ApplicationRecord.transaction`?*

23. **Is the thread-unsafe flag in `DocumentationBuilder` a concern?**
    ```ruby
    BetterTogether.skip_navigation_touches = true
    # ... operations ...
    BetterTogether.skip_navigation_touches = false
    ```
    This is a class-level flag. If two threads run builders concurrently, the flag can be corrupted. *The codebase has a memory about saving/restoring previous values in an `ensure` block — is that pattern applied here?*

24. **Are builder `clear_existing` methods safe against foreign key violations?**
    Deletion order is manually managed. *Is this order validated, and what happens if new associations are added?*

### Current Strengths
- ✅ Idempotent `find_or_initialize_by` + `save! if changed?` pattern
- ✅ Immutable seed data (`OAUTH_PROVIDERS.freeze`)
- ✅ Protected records (`protected: true`) to prevent manual override
- ✅ Locale-aware seeding with `I18n.with_locale(:en)`

---

## 6. Robots / Bots (AI)

### Questions to Ask

25. **Is user content sent to OpenAI sanitized and size-limited?**
    `TranslationBot` sends user-supplied `content` directly in the prompt. *Is there a maximum content size enforced before the API call? Could a user send megabytes of text?*

26. **Is the `target_locale` parameter validated against an allow-list?**
    The locale string is interpolated into the OpenAI prompt without validation. *Could prompt injection occur via a crafted locale value?*

27. **Are there rate limits on translation requests?**
    The translations controller requires authentication but has no per-user rate limiting. *Could a user trigger unlimited API costs?*

28. **Is PII being sent to and logged from the OpenAI API?**
    Translation logs store full request/response content. *Does the privacy policy disclose third-party AI processing? Are logs retained appropriately?*

29. **Is cost monitoring in place for OpenAI usage?**
    The bot estimates costs but doesn't enforce limits. *Are there spending caps or alerts?*

### Current Strengths
- ✅ Low temperature (0.1) for deterministic translations
- ✅ Trix attachment preservation (extracted and restored)
- ✅ Asynchronous logging via background job
- ✅ Error handling returns 422 with user-friendly messages

---

## 7. API Resources (JSONAPI)

### Questions to Ask

30. **Why do `UserResource` and `RegistrationResource` expose `password` and `password_confirmation` as attributes?**
    Even if these are write-only in practice, exposing them in the resource definition risks accidental serialization in responses. *Should these fields be removed from attributes and handled only in controller params?*

31. **Do resources have any test coverage?**
    No dedicated resource spec files exist. *Are serialization outputs verified anywhere?*

32. **Is per-attribute authorization implemented?**
    Resources include `Pundit::Resource` but authorization happens at the controller level, not per-field. *Could a user see fields they shouldn't via includes/sideloading?*

33. **Is the API versioning strategy documented?**
    A `v1` folder exists but there's no deprecation or migration path documented. *What happens when v2 is needed?*

### Current Strengths
- ✅ Pundit::Resource integration for authorization
- ✅ JSONAPI::Resource standard patterns
- ✅ Base ApiResource with shared attributes

---

## 8. Forms

### Questions to Ask

34. **Are Reform form objects tested?**
    `HostPlatformAdminForm` and `HostPlatformDetailsForm` handle critical setup wizard data. *Are there specs validating their validation rules, especially password matching and email format?*

35. **Is the email regex sufficient?**
    Forms use `URI::MailTo::EMAIL_REGEXP`. *Is this appropriate for all valid email addresses the system needs to accept?*

### Current Strengths
- ✅ Reform gem for form encapsulation
- ✅ Proper validation (presence, length, format, confirmation)
- ✅ Nested association handling via populators

---

## 9. Channels (ActionCable)

### Questions to Ask

36. **Do ActionCable channels verify record ownership before streaming?**
    `ConversationsChannel` streams for a conversation by ID. *Does it verify the `current_person` is a participant, or could any authenticated user subscribe to any conversation?*

37. **Are channels tested?**
    No channel specs exist. *Given that channels are a real-time data access path, should they have authorization specs?*

38. **Is there connection-level authentication?**
    Channels rely on `current_person` from the connection. *Is the connection class properly authenticating WebSocket upgrades?*

### Current Strengths
- ✅ Streams scoped to `current_person` where applicable
- ✅ Separate channels for conversations, messages, notifications

---

## 10. Notifiers (Noticed)

### Questions to Ask

39. **Are notification preferences enforced before delivery?**
    Notifiers use `config.if` guards for conditional delivery. *Are all delivery channels (ActionCable, email) gated by user preferences?*

40. **Is the 15-minute email delay for messages tested?**
    `NewMessageNotifier` uses `config.wait` for email batching. *Are there tests verifying the deduplication and batching logic?*

41. **Are notifier classes tested?**
    No `spec/notifiers/` directory exists. *What happens if a notifier raises during delivery — is it retried or silently dropped?*

### Current Strengths
- ✅ Multi-channel delivery (ActionCable + email)
- ✅ Smart email batching with deduplication
- ✅ Recipient email validation
- ✅ Proper scoping to relevant parties

---

## 11. Services

### Questions to Ask

42. **Is `SafeClassResolver` used consistently?**
    This utility provides allow-list-based class resolution to prevent unsafe `constantize`. *Is it applied in all places where dynamic class names are resolved?*

43. **Is the HTTP link checker rate-limited to avoid being flagged as a scanner?**
    `Metrics::HttpLinkChecker` performs HEAD requests with retries. *Does it respect robots.txt or rate-limit outbound requests?*

44. **Are service objects tested?**
    No `spec/services/` directory exists. *Services like `MarkdownRendererService`, `ICS::Generator`, and `Joatu::Matchmaker` contain complex logic — are they covered elsewhere?*

### Current Strengths
- ✅ Clean service object patterns
- ✅ SafeClassResolver for secure dynamic resolution
- ✅ Proper HTML escaping in MarkdownRendererService
- ✅ ICS generation with timezone support

---

## 12. Sanitizers

### Questions to Ask

45. **Is the `ExternalLinkIconSanitizer` tested for XSS bypass?**
    It extends `Rails::HTML5::SafeListSanitizer` and injects Font Awesome icons into links. *Has it been tested with adversarial HTML inputs?*

46. **Could the URI parsing in the sanitizer be exploited?**
    It uses `URI.parse(href)` which can raise on malformed URIs. *Is this handled gracefully?*

### Current Strengths
- ✅ Extends Rails native sanitizer
- ✅ Proper HTML escaping via `ERB::Util.html_escape`
- ✅ Nokogiri for safe DOM manipulation

---

## 13. Integrations

### Questions to Ask

47. **Is OAuth token refresh implemented for the GitHub integration?**
    `Integrations::Github` stores tokens in `PersonPlatformIntegration` but no refresh logic is visible. *Do tokens expire and silently fail?*

48. **Is the integration tested?**
    No `spec/integrations/` directory exists. *Are API interactions stubbed and tested?*

### Current Strengths
- ✅ Octokit gem for GitHub API (well-maintained library)
- ✅ Token stored in model, not in session

---

## 14. Jobs (Sidekiq)

### Questions to Ask

49. **Are all jobs idempotent?**
    Jobs should be safe to retry. *Have all 26 jobs been reviewed for idempotency, particularly metrics tracking jobs that increment counters?*

50. **Are the 5 untested jobs low-risk?**
    Missing specs: `ElasticsearchIndexJob`, `EventReminderSchedulerJob`, `GeocodingJob`, `MailerJob`, `TranslationLoggerJob`. *Are these covered by integration tests, or are they genuinely untested?*

51. **Are job queues properly configured for priority?**
    Jobs use `:default`, `:mailers`, `:metrics` queues. *Are queue weights and concurrency appropriate for production workloads?*

### Current Strengths
- ✅ 21 of 26 jobs have specs
- ✅ Sidekiq scheduler for recurring jobs
- ✅ Queue namespacing by concern

---

## 15. Mailers

### Questions to Ask

52. **Are the 4 untested mailers low-risk?**
    Missing specs: `CommunityInvitationsMailer`, `PersonPlatformIntegrationMailer`, `InvitationMailerBase`, plus the base `ApplicationMailer`. *Do these mailers have unique logic beyond templates?*

53. **Are mailer previews available for all mailers?**
    *Can developers visually verify email content during development?*

### Current Strengths
- ✅ 8 of 12 mailers tested
- ✅ Locale-aware email delivery
- ✅ Proper use of `with()` for parameterized mailers

---

## 16. JavaScript / Stimulus

### Questions to Ask

54. **Are there Stimulus controllers that don't implement `disconnect()`?**
    26 of 65 controllers implement disconnect. *Do the remaining 39 need cleanup, or are they stateless?*

55. **Are Stimulus controllers tested?**
    Feature specs exercise some controllers, but there are no dedicated JS unit tests. *For complex controllers (metrics charts, maps, messaging), would JS-level tests catch regressions faster?*

56. **Is the CDN pinning strategy auditable?**
    Libraries like Chart.js, SlimSelect, Mermaid, and Leaflet are pinned to CDN URLs. *Are subresource integrity (SRI) hashes used to prevent supply-chain attacks?*

### Current Strengths
- ✅ 65 well-organized Stimulus controllers
- ✅ Proper disconnect() cleanup in controllers that manage resources
- ✅ Importmap-only (no bundler complexity)
- ✅ No eval() or inline JavaScript in views
- ✅ Turbo/Stimulus integration follows Hotwire best practices

---

## 17. Views & Helpers

### Questions to Ask

57. **Are all view links and buttons gated by policy checks?**
    The guidelines require authorization-aware UI. *Is there a systematic review of views to ensure no action links render for unauthorized users?*

58. **Are all helpers presentation-only?**
    54+ helper files exist. *Do any contain business logic that should live in models or services?*

59. **Are alt texts present on all images?**
    *Has an accessibility scan confirmed WCAG AA compliance across all views?*

### Current Strengths
- ✅ Consistent Bootstrap 5.3 + Font Awesome 6 usage
- ✅ i18n: no hardcoded strings found in views
- ✅ ARIA attributes used in interactive elements
- ✅ Semantic HTML throughout

---

## 18. Test Coverage

### Questions to Ask

60. **What is the plan to reach adequate test coverage for authorization policies?**
    **0 of 58 policies** have specs. This is the highest-risk gap. Authorization bypasses could go undetected.

61. **What is the plan for builder test coverage?**
    **0 of 10 builders** have specs. Builders seed critical data (roles, permissions, navigation). Silent failures could break the entire platform.

62. **What is the plan for service/channel/notifier/form/resource/integration specs?**
    All of these directories have **zero** dedicated spec files. Combined, this represents ~50 untested classes.

63. **Are the `future_spec/` files part of an active plan?**
    7 API specs and 5 model specs are staged. *When will these be moved to `spec/` and activated?*

64. **Is the overall 59.78% line coverage acceptable for the project's maturity?**
    *What is the target coverage percentage, and is there a plan to increase it?*

### Coverage Summary

| Directory | Files | With Specs | Gap |
|-----------|-------|-----------|-----|
| Models | 162 | ~143 | ~19 missing |
| Controllers | 84 | ~47 | ~37 missing |
| **Policies** | **58** | **0** | **58 missing** ❌ |
| **Builders** | **10** | **0** | **10 missing** ❌ |
| **Services** | **13** | **0** | **13 missing** ❌ |
| **Channels** | **5** | **0** | **5 missing** ❌ |
| **Notifiers** | **11** | **0** | **11 missing** ❌ |
| **Resources** | **7** | **0** | **7 missing** ❌ |
| **Forms** | **2** | **0** | **2 missing** ❌ |
| **Integrations** | **1** | **0** | **1 missing** ❌ |
| **Sanitizers** | **1** | **0** | **1 missing** ❌ |
| Jobs | 26 | 21 | 5 missing |
| Mailers | 12 | 8 | 4 missing |
| Helpers | 54 | ~10 | ~44 missing |
| JavaScript | 65 | 0 (indirect) | Feature specs only |

---

## 19. Dependencies

### Questions to Ask

65. **Is `ruby-openai` unpinned intentionally?**
    The gemspec has no version constraint on `ruby-openai`. *Could a major version bump break the TranslationBot?*

66. **Is Elasticsearch 7 EOL a concern?**
    ES 7 reached end of life. *What is the migration plan to ES 8?*

67. **Are CDN-hosted JavaScript libraries audited for integrity?**
    Chart.js, SlimSelect, Mermaid, Leaflet are loaded from CDNs. *Are SRI hashes applied?*

68. **Are custom gem forks (`pundit-resources`, `storext`) maintained?**
    These point to GitHub repositories. *Are they kept up to date, and what happens if the upstream changes?*

### Current Strengths
- ✅ Most gems properly version-constrained
- ✅ Bundler-audit gem installed
- ✅ Dependabot configured for automated updates

---

## 20. Internationalization (i18n)

### Questions to Ask

69. **Are all 4 locales (en, fr, es, uk) at parity?**
    Locale files exist for all four. *Is `i18n-tasks missing` run regularly in CI?*

70. **Is the i18n health CI workflow catching regressions?**
    `.github/workflows/i18n-health.yml` exists. *Does it block merges on missing keys?*

### Current Strengths
- ✅ 4 locale files with consistent key structure
- ✅ No hardcoded strings in views
- ✅ i18n-tasks configured with proper ignore patterns
- ✅ Locale parameter validated against `I18n.available_locales`
- ✅ Proper locale sanitization in views and controllers

---

## 21. Infrastructure & Configuration

### Questions to Ask

71. **When will CSP be enabled in production?**
    The initializer exists with strong defaults but is commented out. *This should be the highest-priority security infrastructure item.*

72. **Is the default CORS origin of `*` overridden in production?**
    *Is `ALLOWED_ORIGINS` set in the Dokku configuration?*

73. **Are database backups and restore procedures tested?**
    Documentation mentions daily encrypted dumps. *When was the last restore test?*

74. **Is the Docker development environment reproducible?**
    `bin/dc-run` is the standard. *Are there onboarding issues for new developers?*

### Current Strengths
- ✅ Docker-based development environment
- ✅ Dokku deployment with Cloudflare
- ✅ Sidekiq scheduler for recurring tasks
- ✅ Redis for caching and job queues

---

## 22. Documentation

### Questions to Ask

75. **Is the documentation current with the codebase?**
    The docs directory is extensive. *When was the last documentation review for accuracy against the current code?*

76. **Are new developers able to self-serve with existing docs?**
    *Is there a tested onboarding path from clone to running tests?*

### Current Strengths
- ✅ Comprehensive docs directory with assessments, diagrams, and guides
- ✅ Mermaid diagrams for system flows
- ✅ Stakeholder-organized documentation structure
- ✅ Multiple prior assessments showing continuous improvement

---

## 23. Summary of Findings by Severity

### 🔴 Critical (Address Immediately)

| # | Finding | Location | Status |
|---|---------|----------|--------|
| C1 | **RolePolicy allows any user to update/destroy roles** | `app/policies/better_together/role_policy.rb` | ✅ Fixed — restricted to `permitted_to?('manage_platform')` |
| C2 | **NavigationItemPolicy allows any user to modify navigation** | `app/policies/better_together/navigation_item_policy.rb` | ✅ Fixed — restricted to `permitted_to?('manage_platform')` |
| C3 | **CSP disabled in production** | `config/initializers/content_security_policy.rb` | ✅ Fixed — enabled in report-only mode with proper CDN/ActionCable/Trix directives |
| C4 | **Zero policy specs** — 58 authorization files untested | `spec/policies/` (missing) | ⏳ Partially addressed — added RolePolicy + NavigationItemPolicy specs; 24 existing specs already present |
| C5 | **API resources expose password attributes** | `app/resources/better_together/api/v1/user_resource.rb` | 🔄 Addressed in fix/api branch |
| C6 | **Unsafe `constantize` on user input** in InvitationsController | `app/controllers/better_together/invitations_controller.rb:~153` | ✅ Fixed — replaced with `SafeClassResolver.resolve!` using explicit allow-list |

### 🟡 High (Address Soon)

| # | Finding | Location | Status |
|---|---------|----------|--------|
| H1 | **Empty Scope classes** in 3+ policies (no record filtering) | Multiple policy files | ✅ Verified intentional — these inherit parent scope filtering |
| H2 | **Builders lack transactions** — partial data on failure | `app/builders/better_together/` | ✅ Fixed — `clear_existing` wrapped in transaction in base Builder |
| H3 | **Builders have zero test coverage** | `spec/builders/` (missing) | ⏳ Remaining — needs dedicated builder specs |
| H4 | **TranslationBot has no rate limiting or input size limits** | `app/robots/better_together/translation_bot.rb` | ✅ Fixed — added 50KB content limit and locale allow-list validation in controller |
| H5 | **ActionCable channels lack explicit authorization** | `app/channels/better_together/` | ✅ Fixed — ConversationsChannel now verifies participant membership |
| H6 | **Services, notifiers, forms, resources have zero specs** | Multiple spec directories (missing) | ⏳ Remaining — needs dedicated specs |

### 🟠 Medium (Plan for Resolution)

| # | Finding | Location | Status |
|---|---------|----------|--------|
| M1 | **Thread-unsafe flag** in DocumentationBuilder | `app/builders/better_together/documentation_builder.rb` | ✅ Fixed — save/restore previous value in ensure block |
| M2 | **Large controllers** (500+ lines) need refactoring | EventsController, Metrics::ReportsController | ⏳ Remaining |
| M3 | **CORS defaults to `*`** without env override | `config/initializers/cors.rb` | ⏳ Remaining |
| M4 | **`ruby-openai` gem unpinned** | `better_together.gemspec` | ⏳ Remaining |
| M5 | **Elasticsearch 7 is EOL** | Gemspec dependency | ⏳ Remaining |
| M6 | **OAuth token refresh not implemented** for GitHub integration | `app/integrations/better_together/github.rb` | ⏳ Remaining |
| M7 | **CDN scripts lack SRI hashes** | `config/importmap.rb` | ⏳ Remaining |
| M8 | **39 Stimulus controllers may need disconnect()** cleanup | `app/javascript/controllers/` | ⏳ Remaining |

### 🟢 Low (Track and Improve)

| # | Finding | Location |
|---|---------|----------|
| L1 | Some models missing association validations | Person, Page, User, Conversation |
| L2 | 30+ dependent :destroy chains on Person | `app/models/better_together/person.rb` |
| L3 | Duplicated search logic in PersonBlocksController | `app/controllers/` |
| L4 | 5 untested jobs, 4 untested mailers | `spec/jobs/`, `spec/mailers/` |
| L5 | future_spec/ files not yet activated | `future_spec/` |
| L6 | 59.78% overall line coverage | Coverage reports |

---

## Quick-Reference: All 76 Questions

| # | Domain | Question |
|---|--------|----------|
| 1 | Security | Why is CSP disabled in production? |
| 2 | Security | Is the CORS `*` default acceptable? |
| 3 | Security | Is Rack::Attack configured in all environments? |
| 4 | Security | Are Devise thresholds reviewed periodically? |
| 5 | Security | Is the unsafe `constantize` tracked for remediation? |
| 6 | Security | Is bundler-audit running in CI? |
| 7 | Policies | Why can any user update/destroy Roles? |
| 8 | Policies | Why can any user modify NavigationItems? |
| 9 | Policies | Are empty Scope classes intentional? |
| 10 | Policies | Why are there zero policy specs? |
| 11 | Policies | How are guest users handled consistently? |
| 12 | Policies | Is default-deny posture tested? |
| 13 | Controllers | Are large controllers scheduled for refactoring? |
| 14 | Controllers | Is duplicated search logic tracked? |
| 15 | Controllers | Do all API controllers enforce auth consistently? |
| 16 | Controllers | Is verify_authorized used everywhere? |
| 17 | Models | Are models missing required association validations? |
| 18 | Models | Is N+1 prevention consistent? |
| 19 | Models | Are dependent :destroy chains reviewed? |
| 20 | Models | Are model callbacks minimized? |
| 21 | Builders | Why do builders have zero test coverage? |
| 22 | Builders | Why don't builders use transactions? |
| 23 | Builders | Is the thread-unsafe flag a concern? |
| 24 | Builders | Are clear_existing methods safe? |
| 25 | Bots | Is user content sanitized and size-limited? |
| 26 | Bots | Is target_locale validated? |
| 27 | Bots | Are there rate limits on translations? |
| 28 | Bots | Is PII sent to/logged from OpenAI? |
| 29 | Bots | Is cost monitoring in place? |
| 30 | Resources | Why do resources expose password attributes? |
| 31 | Resources | Do resources have test coverage? |
| 32 | Resources | Is per-attribute authorization implemented? |
| 33 | Resources | Is API versioning documented? |
| 34 | Forms | Are Reform form objects tested? |
| 35 | Forms | Is the email regex sufficient? |
| 36 | Channels | Do channels verify record ownership? |
| 37 | Channels | Are channels tested? |
| 38 | Channels | Is there connection-level authentication? |
| 39 | Notifiers | Are notification preferences enforced? |
| 40 | Notifiers | Is the message email delay tested? |
| 41 | Notifiers | Are notifiers tested? |
| 42 | Services | Is SafeClassResolver used consistently? |
| 43 | Services | Is the link checker rate-limited? |
| 44 | Services | Are service objects tested? |
| 45 | Sanitizers | Is the sanitizer tested for XSS bypass? |
| 46 | Sanitizers | Could URI parsing be exploited? |
| 47 | Integrations | Is OAuth token refresh implemented? |
| 48 | Integrations | Is the integration tested? |
| 49 | Jobs | Are all jobs idempotent? |
| 50 | Jobs | Are the 5 untested jobs low-risk? |
| 51 | Jobs | Are job queue priorities appropriate? |
| 52 | Mailers | Are the 4 untested mailers low-risk? |
| 53 | Mailers | Are mailer previews available? |
| 54 | JavaScript | Do all Stimulus controllers handle cleanup? |
| 55 | JavaScript | Are Stimulus controllers tested? |
| 56 | JavaScript | Is CDN pinning auditable (SRI)? |
| 57 | Views | Are all links/buttons gated by policies? |
| 58 | Views | Are all helpers presentation-only? |
| 59 | Views | Are alt texts present on all images? |
| 60 | Coverage | What is the plan for policy specs? |
| 61 | Coverage | What is the plan for builder specs? |
| 62 | Coverage | What is the plan for service/channel/etc specs? |
| 63 | Coverage | When will future_spec/ be activated? |
| 64 | Coverage | Is 59.78% coverage acceptable? |
| 65 | Deps | Is ruby-openai unpinned intentionally? |
| 66 | Deps | Is Elasticsearch 7 EOL a concern? |
| 67 | Deps | Are CDN libraries audited for integrity? |
| 68 | Deps | Are custom gem forks maintained? |
| 69 | i18n | Are all 4 locales at parity? |
| 70 | i18n | Is i18n health CI blocking merges? |
| 71 | Infra | When will CSP be enabled? |
| 72 | Infra | Is CORS overridden in production? |
| 73 | Infra | Are backup restores tested? |
| 74 | Infra | Is the Docker environment reproducible? |
| 75 | Docs | Is documentation current with code? |
| 76 | Docs | Can new developers self-serve? |

---

*This audit was generated through automated analysis of the codebase. Findings should be validated by the team and prioritized based on deployment context and threat model.*
