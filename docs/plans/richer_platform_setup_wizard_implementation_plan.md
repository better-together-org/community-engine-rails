# Implementation Plan: Richer, Unified Platform-Provisioning Wizard

**Date:** July 18, 2026
**Companion to:** [`docs/assessments/richer_platform_setup_wizard_assessment.md`](../assessments/richer_platform_setup_wizard_assessment.md)
**Status:** Planning only — no code changes are made against these items in this document. Each phase below is scoped for a future implementation PR.

Scope decisions (per explicit user direction on this plan):
- **Member provisioning stays scoped to the existing staff-invite mechanism** (`PlatformInvitationsController`) — building the confirmed-missing self-service "request to join a platform" controller is explicitly **out of scope**.
- **One unified wizard** covers both the free/ops provisioning path and the billing-gated paid path (PR #1581) — not two separate flows.

---

## Architecture

### Core decision: one `Wizard` row minted per provisioning run

Following the assessment's "Option A": at kickoff, create a **draft `Platform`** and, in the same transaction, a **paired `Wizard`** row (`identifier: 'new_platform_setup'`, `platform: draft_platform`). This is the natural fit for the schema as it already exists (`Wizard#platform_id` + `PlatformScoped` + platform-scoped `Identifier` uniqueness, confirmed in the assessment) and avoids inventing a new "which run is this" concept — the pairing itself *is* the run identifier.

Resolution then becomes:
```ruby
def wizard
  @wizard ||= ::BetterTogether::Wizard.for_platform(target_platform).find_by(identifier: 'new_platform_setup')
end
```
replacing the `host_setup_wizard`-style bare `find_by`. `target_platform` is resolved from a URL param (the draft platform's id/slug) once step 1 creates it, or carried in the session between the pre-kickoff step and step 1.

Each step definition needs its own `WizardStepDefinition` row (built by a new `NewPlatformSetupWizardBuilder`, mirroring `SetupWizardBuilder`'s pattern, but invoked per-run rather than once at `db:seed` time — likely via a `before_action` that lazily creates the Wizard + its step definitions the first time a person hits the entry route with no existing in-progress run).

### Controllers

New `NewPlatformSetupController` / `NewPlatformSetupStepsController`, structurally mirroring `SetupWizardController`/`SetupWizardStepsController` (per the assessment: the generic `WizardStepsController#update` is an unimplemented stub, so every step needs a hand-written action exactly like the existing pattern, not a shortcut).

Each needs to override:
- `#wizard` — as above, platform-scoped, not the generic unscoped lookup.
- `#wizard_step_path` — pointing at new named routes.
- A local `SafeClassResolver` allow-list, e.g. `NEW_PLATFORM_SETUP_FORM_CLASSES = %w[BetterTogether::NewPlatformIdentityForm BetterTogether::NewPlatformDomainForm BetterTogether::NewPlatformStewardForm BetterTogether::NewPlatformInviteForm]` (new Reform-style form classes, one per step that needs one; the welcome and review steps likely don't need a backing model form).
- An `ensure_setup_wizard_incomplete`-equivalent guard, but scoped to **this platform's** wizard, not global — a person should be able to start a *new* provisioning run for a *different* platform even if a previous run completed, so the guard checks `wizard.completed?` for the specific in-progress platform's Wizard row, not a singleton.

### Entry points (unified)

1. **Ops/internal entry** — a new authenticated route (`manage_platform`-permissioned, i.e. platform_steward/platform_manager on some existing platform, or a network-level permission if this is meant to be usable by network admins provisioning on behalf of a client) that creates the draft Platform + Wizard and redirects to step 1. This supersedes `PlatformsController#new/#create`'s bare CRUD form as the primary "add a platform" surface for internal/BTS use — that controller's `new` action currently defaults `external: true`, suggesting it was really meant for registering federated/external platforms, not provisioning new internally-hosted ones, so this isn't a redundant replacement, just a clarification of intent.
2. **Billing-gated entry** — `CommunityBillingsController#provision_platform`/`#create_platform_provision` becomes the **entitlement pre-check + kickoff redirect**, not its own separate provisioning form:
   ```ruby
   def create_platform_provision
     @hosted_entitlement = hosted_entitlement_resolver.call(community: @community)
     return redirect_to_billing_with_alert(...) unless @hosted_entitlement.active?
     draft = ::BetterTogether::TenantPlatformProvisioningService.call(name: nil, host_url: nil, ...) # or a lighter draft-only creation path
     redirect_to new_platform_setup_step_path(:platform_identity, wizard_id: ...)
   end
   ```
   The exact mechanics of "create just enough of a draft Platform to hang a Wizard off of, before the person has entered a name/host_url" need a small design decision during implementation (e.g., a nullable-name draft state on `Platform`, or defer Wizard creation until step 1 collects the minimum `TenantPlatformProvisioningService` needs) — flagged here as an open implementation-time question, not resolved in this planning pass.
   The entitlement check happens **once, at this kickoff point** — matching PR #1581's already-tested behavior exactly (don't re-check per step; there is no capacity/seat concept to re-validate against, per the assessment).

---

## Step Sequence

Six steps, adapted from the unused 8-step YAML's ideas but not copied verbatim — each justified against what actually needs collecting for *this* codebase's models, not the fixture's aspirational form classes.

### Step 1 — Welcome / locale
- Field: `locale` (reuse whatever locale-select helper the existing `welcome` fixture step specifies).
- Content: replaces the fixture's vague "land acknowledgment" language with real informational copy about what's about to happen — can reuse the "What happens next" bullet copy already written for `provision_platform.html.erb` (PR #1581) almost verbatim, since it already accurately describes this wizard's own steps 2-4.
- No model to persist beyond locale/session state.

### Step 2 — Platform identity
- Fields: `name`, `description`, `privacy` (`Platform#privacies`), `time_zone` (`iana_time_zone_select` helper, same as `platform_details.html.erb` and `PlatformDomainsController`'s form use today).
- **Merges** the old fixture's separate `community_identity`/`privacy_settings`/`time_zone` steps into one — they're all attributes of the same `Platform` record and a `HostPlatformDetailsForm`-style Reform object already handles exactly this field set for the host platform; the assessment found no evidence the 3-way split was a deliberate UX decision (it's unimplemented fixture data), so collapsing them removes friction without discarding a proven pattern.
- New form class: `NewPlatformIdentityForm` (Reform, modeled directly on `app/forms/better_together/host_platform_details_form.rb`).
- On submit: create/update the underlying `Platform` (via `TenantPlatformProvisioningService`, or the same `assign_attributes` + `set_as_host`-equivalent pattern `SetupWizardStepsController#create_host_platform` uses, minus the host-specific bits — `set_as_host` must NOT be called here, since this platform is explicitly non-host).

### Step 3 — Domain
- **New step, not in the old fixture.** Reuses the subdomain-vs-custom-domain picker built for `PlatformDomainsController` (`app/views/better_together/platform_domains/_form.html.erb`, `app/javascript/controllers/better_together/platform_domain_form_controller.js` — both confirmed present in the current codebase) directly, rather than re-implementing it. This closes the gap the PR #1677 assessment flagged (domain choice happening only as a separate later admin action) by folding it into initial provisioning.
- Practically: either literally render the existing `_form` partial in this step's template (passing the draft platform + a new/blank `PlatformDomain`), or extract its field markup into a reusable partial both `PlatformDomainsController` and this wizard step render — an implementation-time choice, not resolved here, but the reuse *target* is settled: don't rebuild the picker.

### Step 4 — Steward account
- Fields: `email`, `password`/`password_confirmation`, nested `person` (`identifier`, `name`, `description`) — identical field set to the existing `HostPlatformAdminForm`/`admin_creation.html.erb` step.
- New form class: `NewPlatformStewardForm`, structurally copying `app/forms/better_together/host_platform_admin_form.rb`.
- On submit: create the `User`/`Person`, then `PersonPlatformMembership(role: platform_steward)` + `PersonCommunityMembership(role: community_governance_council)` **on the new platform's own primary community**, generalizing `SetupWizardStepsController#create_admin`'s hardcoded `helpers.host_platform`/`helpers.host_community` calls to the wizard's `target_platform`/`target_platform.primary_community`.
- Note: `platform_steward` and `platform_manager` are functionally identical (per the assessment) — defaulting to `platform_steward` here is fine; no functional difference if a future maintainer prefers `platform_manager`.

### Step 5 — Invite first members (optional, skippable)
- Embeds the existing `PlatformInvitationsController` creation form's field set (email, required `community_role`, optional `platform_role`) for 0-N invitees, per the user's staff-invite-only scope decision.
- A "Skip for now" affordance is required — this step must not block wizard completion, since a platform with zero non-steward members is a completely valid end state.
- No new invitation infrastructure — this step is a thin UI wrapper that calls `PlatformInvitation.create!` (or the controller's existing `create` action logic, invoked internally) once per entered invitee, exactly as `PlatformInvitationsController#create` already does today.

### Step 6 — Review & launch
- **Genuinely new pattern** — no "review and confirm" step exists anywhere else in this app (confirmed in the assessment). Read-only recap of steps 2-5's choices (platform name/privacy/time zone, domain, steward email, pending invitations), each with an accessible "Edit [section]" link back to the relevant step.
- Final confirmation marks the Wizard's last step complete, `determine_wizard_outcome` redirects to `success_path` (likely the new platform's own dashboard/show page, or the steward's sign-in page if they need to confirm their email first — mirroring `host_setup`'s email-confirmation flow).
- Because there's no existing precedent, this step needs the most deliberate accessibility design (below) and the most implementation-time scrutiny generally.

---

## Accessibility Design

Concrete fixes for the gaps the assessment identified — not a repeat of the existing wizard's partial pattern:

1. **Step list, not just a bar.** An `<ol>` of the 6 step names, each `<li>` marked `aria-current="step"` on the active one (in addition to keeping the existing `role="progressbar"` percentage bar, which remains useful as a supplementary visual/AT cue).
2. **Accessible error summary.** On validation failure: a summary block with `role="alert"`, `tabindex="-1"`, populated with links to each invalid field, and JS moves focus to it on render — the current wizard has none of this; it must be built fresh, not copied.
3. **`aria-describedby` wiring.** Every field's hint `<small>` gets an `id`, referenced by the input's `aria-describedby` — matching `spec/features/better_together/reports_accessibility_spec.rb`'s pattern (the assessment's cited reference implementation), not the current wizard's unwired hints.
4. **Step 6 edit links.** Each recap section's "Edit" link needs a full accessible name via visually-hidden text or `aria-label` (e.g. "Edit platform identity"), never a bare repeated "Edit" ×4/5.
5. **Skip-step affordance (step 5) announced correctly** — a real `<button>`/link, not a JS-only skip, so it's keyboard- and AT-reachable without relying on visual layout.

**Mandatory test coverage** (per `docs/development/accessibility_testing.md` — a hard requirement, not optional polish): a new `spec/features/better_together/new_platform_setup_wizard_accessibility_spec.rb`, `:js`, running axe-core against `:wcag2a, :wcag2aa, :wcag21a, :wcag21aa`, executed across **all four supported locales** (en/fr/es/uk) for at least the identity, domain, and review steps (the three most content/form-heavy). This spec must exist before any implementation PR touching this wizard is considered complete — the standard explicitly states a UI change "is not considered accessible if it only passes in the default locale."

---

## i18n Structure

Follow the existing convention exactly (confirmed in `config/locales/en.yml`'s `wizard_step_definitions.host_setup.*` tree):

```yaml
better_together:
  wizard_step_definitions:
    new_platform_setup:
      welcome: { hero: {...}, intro: ..., progress: { step: "Step 1 of 6" }, buttons: { next: ... } }
      platform_identity: { hero: {...}, fields: { name: {...}, ... }, progress: { step: "Step 2 of 6" }, errors: {...} }
      domain: { ... }
      steward_account: { ... }
      invite_members: { ..., buttons: { skip: "Skip for now", next: ... } }
      review_and_launch: { ..., edit_links: { platform_identity: "Edit platform identity", domain: "Edit domain", ... } }
  new_platform_setup_steps:          # controller-level flash namespace, mirrors setup_wizard_steps.*
    already_completed: ...
    create_platform_identity:
      flash: { please_address_errors: ... }
    # one block per POST action, matching the setup_wizard_steps.* precedent
```
Relative/lazy `t('.foo')` lookups in views throughout, exactly as the existing wizard views do — no hardcoded full key paths.

---

## Sequencing for Future Implementation PRs (risk-ordered)

1. **Wizard/controller scaffolding + Steps 1, 2, 4** (welcome, identity, steward) — closest analog to existing `host_setup` code, lowest risk, establishes the `#wizard` platform-scoping override and the per-run Wizard-minting pattern that every later phase depends on.
2. **Step 3 (domain)** — thin integration of the already-shipped, already-tested `PlatformDomainsController` picker UI. Low risk, mostly a reuse/wiring exercise.
3. **Step 5 (invite members)** — thin integration of the already-shipped, already-tested `PlatformInvitationsController`. Low risk, same reasoning.
4. **Step 6 (review & launch) + the full accessibility spec suite** — highest novelty (no existing pattern), do last, with the most review scrutiny. This phase is also where the `NEW_PLATFORM_SETUP_FORM_CLASSES` allow-list and the accessible error-summary/step-list components should be finalized, since by this point all the step types they need to support exist.
5. **Billing entry-point wiring** (`CommunityBillingsController#provision_platform` → kickoff redirect) — depends on PR #1581's merge status; re-check before starting this phase, same discipline as the `admin:`→`steward:` signature watch already tracked for that PR elsewhere. If #1581 has changed its provisioning params shape by the time this phase starts, adjust the kickoff redirect's draft-creation call accordingly.

**Known edge case, explicitly deferred, not solved by this plan:** a billing subscription that transitions to `past_due`/canceled *while* a person is mid-wizard (after the one-time entitlement check at kickoff) is out of scope — the wizard does not re-validate entitlement per step. Flagging this now so it isn't rediscovered as a surprise during phase 5 implementation.

---

## Summary Table

| Phase | Scope | Risk | Depends on |
|---|---|---|---|
| 1 | Wizard/controller scaffolding, steps 1/2/4 | Low | None |
| 2 | Step 3 (domain) | Low | Phase 1 |
| 3 | Step 5 (invite members) | Low | Phase 1 |
| 4 | Step 6 (review & launch) + accessibility spec suite | Medium — genuinely new pattern | Phases 1-3 |
| 5 | Billing entry-point wiring | Medium — depends on external PR #1581 | Phase 1; PR #1581 merge status |
