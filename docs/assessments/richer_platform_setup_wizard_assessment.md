# Richer Platform Setup Wizard — Current-State Assessment

**Date:** July 18, 2026
**Assessment Type:** Architecture and gap assessment for platform-provisioning UX
**Repository:** better-together-org/community-engine-rails
**Scope:** The generic Wizard framework, the existing host-setup flow, the billing-gated provisioning path (PR #1581), member/steward provisioning mechanisms, and accessibility conventions — assessed together because a richer, unified platform-setup wizard has to sit on top of all four.

---

## Executive Summary

Two disconnected surfaces currently cover pieces of "create a new platform," and neither is a complete, accessible onboarding experience:

- **`SetupWizardController`/`SetupWizardStepsController`** — a real, working, 2-step wizard (`platform_details` → `admin_creation`), but hardcoded to the single singleton host platform. It cannot provision additional tenant platforms as written.
- **`CommunityBillingsController#provision_platform`** (open PR #1581) — a single-page form gated by a billing entitlement check, which explicitly defers steward/member setup to "after provisioning" — a step that doesn't exist yet.

The generic `Wizard`/`WizardStep`/`WizardStepDefinition` framework was already partially retrofitted for per-platform use (a `platform_id` column exists on `Wizard`), but nothing in the codebase actually uses that capability yet. A frequently-cited "8-step" richer wizard design turns out to be unused fixture data from an unrelated PR, not an approved product spec — this assessment corrects that record. Billing "entitlement" is platform-existence-level only; there is no member/seat gating anywhere to design around. Member and steward provisioning are two already-distinct, already-built mechanisms that a new wizard should call into, not reinvent. The current wizard's accessibility is partial at best against this repo's own documented WCAG 2.1 AA standard.

---

## 1. The Generic Wizard Framework

### 1.1 Models

`app/models/better_together/wizard.rb` (`Wizard < PlatformRecord`, includes `Identifier`, `Protected`):
- `has_many :wizard_step_definitions` (ordered), `has_many :wizard_steps`.
- Fields: `identifier`, `max_completions` (int, default 0 = unlimited), `current_completions`, `first_completed_at`, `last_completed_at`, `success_message`, `success_path`.
- `completed?` returns `current_completions.positive?` (a side-effecting method — it calls `mark_completed` first if all steps are done) — this is an **aggregate, whole-row completion counter**, not a per-person "have I finished this run" flag.
- `mark_completed` increments `current_completions` once all `wizard_steps` are complete, capped at `max_completions`.

`app/models/better_together/wizard_step.rb` (`WizardStep < PlatformRecord`):
- `belongs_to :wizard`, `belongs_to :wizard_step_definition`, `belongs_to :creator` (optional, `Person`).
- **No column referencing "the platform being provisioned."** Progress is keyed by `(wizard_id, identifier, creator_id)` only.
- Validation `unique_uncompleted_step_per_person`: blocks a second concurrent *uncompleted* step for the same `(wizard_id, identifier, creator_id)` triple — but different `creator_id`s never collide, so **the framework already supports multiple people running the same Wizard row concurrently**, just not one person running it twice at once against the same row.
- Validation `validate_step_completions`: once `wizard.max_completions` completions exist **across all creators** for a given step identifier, no more can complete — this is what makes `host_setup` (`max_completions: 1`) a true one-time global gate.

`app/models/better_together/wizard_step_definition.rb`:
- `identifier`, `template`, `form_class` (plain string column — never `constantize`d directly), `message`, `step_number` (unique per `wizard_id`).
- `form_class` is only ever resolved through `BetterTogether::SafeClassResolver.resolve!(name, allowed: [...])` — an explicit allow-list the calling controller must supply. There is no global registry of permitted wizard form classes.

### 1.2 Per-platform scoping — schema-ready, code-unused

**Confirmed:** `db/migrate/20260606001008_add_platform_id_to_wizards.rb` (verbatim):
```ruby
# Phase 5 — Wizard isolation.
# Each platform can have its own onboarding wizard(s).
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToWizards < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_wizards, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms }, index: true
  end
end
```
`Wizard` includes `PlatformScoped` (confirmed via the shared example `it_behaves_like 'platform scoped identifier', factory: :better_together_wizard` in `spec/models/better_together/wizard_spec.rb:126`), and `Identifier`'s uniqueness validation is scoped to `platform_id` whenever the model has that column — so multiple `Wizard` rows sharing `identifier: 'new_platform_setup'`, one per `platform_id`, is not a collision; `.for_platform(platform)` is the ready-made scope to fetch "the wizard for platform X."

**But nothing consumes this.** `app/helpers/better_together/application_helper.rb:345-348`:
```ruby
def host_setup_wizard
  ::BetterTogether::Wizard.find_by(identifier: 'host_setup') ||
    raise(StandardError, 'Host Setup Wizard not configured. Please run rails db:seed')
end
```
— a bare, unscoped lookup. There is exactly one seeded `host_setup` `Wizard` row in the whole codebase (`app/builders/better_together/setup_wizard_builder.rb`), and nothing anywhere creates a second, non-host `Wizard` row or calls `.for_platform` on one. **This is the single most important architectural finding for a richer wizard**: the schema already supports per-platform wizard runs, but every piece of code that would make use of it (a `#wizard` resolver override, a per-run Wizard-minting flow, a subject-record link between a `WizardStep` and the platform being built) still needs to be written.

### 1.3 Controllers

`app/controllers/concerns/better_together/wizard_methods.rb` (fully generic base): `determine_wizard_outcome`, `find_or_create_wizard_step`, `mark_current_step_as_completed`, and `#wizard` (`Wizard.find_by(identifier: wizard_identifier)` — again, unscoped). Any new per-platform wizard controller **must override `#wizard`** to resolve via `.for_platform`, exactly the way `SetupWizardController` already overrides it to `helpers.host_setup_wizard` instead of relying on the generic lookup.

`app/controllers/better_together/wizard_steps_controller.rb`'s generic `#update` action is an **unimplemented stub** (a bare comment, no code). All real step-transition logic lives in `SetupWizardStepsController`'s bespoke, hand-written per-step actions (`create_host_platform`, `create_admin`) — there is no reusable "just declare steps and get transitions for free" path. A new wizard needs the same hand-rolled treatment.

### 1.4 The "8-step" design — corrected provenance

`config/seeds/better_together/wizards/host_setup_wizard.yml` describes an unused 8-step flow: `welcome` (locale), `community_identity` (name/description/logo), `privacy_settings` (url/privacy), `admin_creation`, `time_zone`, `purpose_and_features` (multi-select use-cases), `first_welcome_page` (rich-text welcome message), `review_and_launch`. Its form classes (`::BetterTogether::HostSetup::WelcomeForm` etc.) **do not exist anywhere in the codebase**.

`git log --follow` on this file shows it was added by PR #790, "Add BetterTogether::Seed" — a PR entirely about building the generic Seedable/Seed-loading infrastructure, not about redesigning onboarding. This YAML is illustrative fixture data exercising that new seed format, later commits in the same PR fix its `type:` field purely for the seed loader's sake. **No PR description, comment, or doc anywhere narrates a deliberate decision to ship 8 onboarding steps.** Its `success_path: "/"` also differs from the actually-seeded `success_path: '/users/sign-in'` — a further sign this is draft/fixture, not live config.

**Correction for future readers:** treat this YAML's step list as a source of ideas, not a specification. Citing it as "the planned richer wizard design" would be as inaccurate as citing the superseded `multi_tenancy_gap_assessment_2026-03-11.md` as current architecture (see that document's own superseded-by banner, added in a prior assessment pass, for the same category of mistake).

---

## 2. The Billing-Gated Provisioning Path (PR #1581)

**Status at time of writing:** PR #1581 ("Stripe-first community billing foundation") is open, not yet merged, targeting `release/0.11.0-notes`.

### 2.1 `HostedEntitlementResolver`

`app/services/better_together/billing/hosted_entitlement_resolver.rb` — single method `call(community:, billing_subscription: nil)`, returns a `Result` struct with a tri-state `hosted_status` (`:active`/`:attention`/`:inactive`):
```ruby
def hosted_status_for(subscription)
  return :inactive if subscription.blank?
  return :attention if subscription.status == 'past_due'
  return :active if subscription.activeish?
  :inactive
end
```
`activeish?` (on `Billing::Subscription`, delegating `status` to the Pay-gem's `Pay::Subscription`) is `status.in?(%w[trialing active past_due])` — so `past_due` is both "activeish" (access continues) and separately flagged as needing attention.

### 2.2 What the entitlement actually gates — platform existence, nothing else

`Result#hosted_access_level`, `#support_tier`, `#community_capacity_tier` are **pure pass-throughs from `Billing::Plan` metadata** — plain string labels with **zero enforcement code anywhere in the branch** (confirmed by exhaustive grep across `app/models/better_together/billing/` and `app/services/better_together/billing/` for `community_capacity_tier|member_limit|seat|capacity`). `community_capacity_tier` is displayed on the billing dashboard purely as a cosmetic label — nothing compares it to a member count, nothing derives a remaining-capacity number from it.

The only real gate in the entire billing branch is `CommunityBillingsController#provision_platform`/`#create_platform_provision`:
```ruby
def create_platform_provision
  @hosted_entitlement = hosted_entitlement_resolver.call(community: @community)
  return redirect_to_billing_with_alert(...) unless @hosted_entitlement.active?
  handle_provision_result(::BetterTogether::TenantPlatformProvisioningService.call(**platform_provision_params_hash))
end
```
Permitted params: `name`, `host_url`, `time_zone` (default `America/St_Johns`), `privacy` (default `private`) — **no steward params**. The form's own "What happens next" copy states plainly: *"Platform stewardship access can be configured after provisioning."* This is the exact seam a richer wizard needs to fill — there is currently nothing on the other side of that sentence.

Confirmed tested (`spec/requests/better_together/community_billings_spec.rb`): active entitlement → service called with exactly those 4 keys; `past_due` or no subscription → service never invoked, redirect with alert. No pending/TODO specs suggest this gate itself needs rework — it's a clean, small, already-correct integration point.

---

## 3. Member vs. Steward Provisioning — Two Already-Distinct Mechanisms

| | Ordinary platform "member" | Platform "staff" (steward/manager/etc.) |
|---|---|---|
| Record | `PersonCommunityMembership` on the platform's **host community** | `PersonPlatformMembership` |
| Created via | Registration (default `community_member` role) or the community-level `MembershipRequest`/invitation system | `PlatformInvitationsController` (staff-only) or direct staff assignment |
| Self-service? | Only if `allow_membership_requests: true` **and** `requires_invitation: false` — both default the opposite way, so off unless a steward opts in | **Never** — `PersonPlatformMembershipsController` requires `manage_platform_members`/`manage_platform_roles`, restricted to people already in the host community |

`PlatformInvitationsController` (`app/controllers/better_together/platform_invitations_controller.rb`) is the existing, fully-built, staff-only tool: sets a required `community_role` and an optional `platform_role`, accepted through the Devise registration form via a token (`registers_user?` → true). On acceptance, `InvitationSessionManagement#handle_platform_invitation_acceptance` creates an active `PersonPlatformMembership` with the specified `platform_role`, or falls back to a role literally called **`platform_member`** (seeded outside `AccessControlBuilder` via migration `20260320235959_seed_platform_member_role_before_host_backfill.rb`, permission set: `read_platform` only) — this is the genuine "plain member" platform role, just not part of the canonical role-builder list.

**Confirmed dead route:** `config/routes.rb:340-341` declares `resources :membership_requests, only: %i[index show destroy], controller: 'platform_membership_requests'` nested under `platforms` — no `PlatformMembershipRequestsController` exists anywhere in the codebase. This is aspirational/dead routing, not a working self-service "request to join a platform" feature. (Per the user's decision for the companion implementation plan, building this is explicitly out of scope — the wizard's member-provisioning step reuses the existing staff-invite mechanism instead.)

**Also worth flagging:** `platform_steward` and `platform_manager` carry byte-for-byte identical permission lists in `app/builders/better_together/access_control_builder.rb` (lines 151-198, verified verbatim) — 20 permissions each, in the same order. They are peers, not a hierarchy, despite the naming suggesting otherwise. Not a blocker for this design, but worth a maintainer's attention separately.

---

## 4. Accessibility — Partial Model, Not a Template

The existing 2-step wizard (`app/views/better_together/wizard_step_definitions/host_setup/{platform_details,admin_creation}.html.erb`) has:
- ✅ A `role="progressbar"` bar with `aria-valuenow`/`aria-valuemin`/`aria-valuemax`.
- ❌ No `aria-current="step"` on any step indicator (there's no step list at all, just one bar).
- ❌ No `aria-live` region and no scripted focus-move on validation errors — the error block is a plain `.alert.alert-danger` div with no `role="alert"`.
- ❌ Help `<small>` text is not wired to its input via `aria-describedby`.

These are real, current gaps — not conventions a new wizard should replicate.

The authoritative standard is `docs/development/accessibility_testing.md` + `.github/instructions/accessibility.instructions.md`: WCAG 2.1 AA via axe-core, explicitly **required in all four supported locales (en/fr/es/uk)** for any multi-step or interactive flow, with `spec/features/better_together/reports_accessibility_spec.rb` cited as the actual reference implementation for correct `aria-describedby`, consent-guidance, and focus patterns — not the host_setup wizard. The Gemfile confirms real tooling is present: `axe-core-capybara`, `axe-core-rspec`, `axe-core-selenium`.

No "review and confirm" (read-only recap before final submit) pattern exists anywhere in this codebase today. Introducing one for a richer wizard is a genuinely new UI pattern here, not a divergence from an existing one.

---

## 5. Summary Table

| Component | State | Reusable as-is? |
|---|---|---|
| `Wizard`/`WizardStep`/`WizardStepDefinition` models | Per-platform scoping schema-ready, unused | Yes, as the framework foundation |
| `WizardMethods`/`WizardsController`/`WizardStepsController` | Generic base; `#update` unimplemented; `#wizard` unscoped | Partially — must override `#wizard`, hand-write step actions |
| `SetupWizardController`/`SetupWizardStepsController` | Real, working, host-platform-only | As a pattern to mirror, not extend directly |
| 8-step YAML design | Unused fixture data from an unrelated PR | As inspiration only, not a spec |
| `HostedEntitlementResolver` / billing gate | Real, tested, platform-existence-level only | Yes, as the wizard-kickoff gate |
| `PlatformInvitationsController` | Real, tested, staff-only | Yes, for the invite-members step |
| `PersonPlatformMembershipsController` | Real, tested, staff-assigns-staff only | Yes, underlying the steward-creation step |
| Platform-level membership requests | Route exists, controller does not | No — confirmed dead, out of scope per user decision |
| Wizard accessibility | Partial; real gaps against documented standard | No — needs deliberate new design, see companion plan |

## Related Documents

- `docs/plans/richer_platform_setup_wizard_implementation_plan.md` — the architecture and step-sequence design building on this assessment.
- `docs/releases/0.11.0_setup_wizard_and_platform_bootstrap.md` — the existing host-setup bootstrap evidence packet (accurate for what it covers; explicitly scoped to bootstrap-only, not richer onboarding).
- `docs/assessments/release_0_11_0_multi_platform_federation_readiness_assessment.md` — the broader 0.11.0 multi-platform assessment this work extends.
