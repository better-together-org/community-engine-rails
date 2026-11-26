---
name: agreement-mechanism
description: Use before adding or changing any screen, flow or service where a person reads and accepts an agreement (sign-up, publishing, community creation, checkout, any new gate). Reuse the shared agreement modal and acceptance recorder; never build a second one.
---

# Agreement acceptance: reuse the shared mechanism

Every place a person has to read and accept an `BetterTogether::Agreement` uses one mechanism. It
exists, it is tested, and it records acceptance in one way. Do not write inline terms with a bare
checkbox, a new modal, a new Stimulus controller, or a second way of storing acceptance. If the
shared mechanism cannot do what you need, extend it and say so in the PR.

## The pieces

| Piece | Where | Job |
|---|---|---|
| Modal shell | `app/views/layouts/better_together/_agreement_modal_shell.html.erb` (rendered once by the application layout) | `#agreementModal`, `#agreement_modal_frame`, the "I agree" footer |
| Open and accept | `app/javascript/controllers/better_together/agreement_modal_controller.js` | Opens the modal for any `.agreement-modal-link`, posts direct accepts |
| Read to the end | `app/javascript/controllers/better_together/agreement_view_controller.js` | Unlocks the matching checkbox, or the "I agree" button, once the agreement has been scrolled to the end |
| Naming helpers | `BetterTogether::AgreementsHelper` (`agreement_acceptance_param_name`, `agreement_acceptance_checkbox_id`) | Parameter name is `<identifier>_agreement` with value `'1'` |
| Recording | `BetterTogether::AgreementAcceptanceRecorder.record!` | The only writer of acceptance records |
| Direct accept | `POST` member route `accept` on agreements (`AgreementsController#accept`) | For modal-only accepts with no form |

## Two modes. Pick one.

1. **Checkbox unlock** (default, used by sign-up and checkout). The form carries the box; the modal
   only unlocks it.
   - Link: `class: 'agreement-modal-link'`, `data: { agreement_identifier: agreement.identifier }`, `href` is `agreement_path(agreement, locale: I18n.locale)`.
   - Box: `check_box_tag agreement_acceptance_param_name(agreement), '1', false, class: 'form-check-input agreement-checkbox', required: true, data: { agreement_identifier: agreement.identifier }, aria: { describedby: summary_id, disabled: 'true' }`.
   - The box stays locked until the review completes. Never enable it yourself.
2. **Direct accept** (used by the publishing and community-creation notices). A link with
   `data: { agreement_mode: 'direct_accept', agreement_accept_url: <accept path> }`; the modal's "I agree" button posts the acceptance. See `shared/_publishing_agreement_notice.html.erb`.

Reference implementations: `app/views/devise/registrations/new.html.erb` (checkbox unlock),
`app/views/better_together/billing/checkouts/new.html.erb` (checkbox unlock with stable ids),
`app/views/better_together/shared/_publishing_agreement_notice.html.erb` (direct accept).

## Server side

- Read ticks with `params[helpers.agreement_acceptance_param_name(agreement)] == '1'`. Do not invent
  `accepted_ids[]` style parameters.
- Record with `AgreementAcceptanceRecorder.record!(agreement:, participant:, acceptance_method:, context:)`.
  Wrap it in a service when a flow has its own rules (see `Billing::Checkout::AgreementGate`), but
  the service calls the recorder; it does not write rows itself.
- Enforce on the server every time. The locked box is a courtesy, not a gate: the controller must
  refuse when something required is missing, and a second check belongs where the thing is created.
- Only active agreements are offered. A draft must never be shown for acceptance.

## Checklist for a change

1. Search first: `git grep -n 'agreement-modal-link\|agreement-checkbox\|AgreementAcceptanceRecorder'`.
2. Reuse the link, box, helpers and recorder as above. No inline `term.content` rendering in place of the modal.
3. Keep stable DOM ids for the link and the box and lock them in a `spec/dom_contracts` spec.
4. Add a `:js` feature spec that opens the modal, scrolls `#agreement_modal_frame`'s `.modal-body` to the end and expects the box to unlock (model: `spec/features/better_together/billing/checkout_agreement_modal_spec.rb`).
5. Add a request spec that posts with and without the ticks and expects the refusal.
6. For view changes follow the screenshot rules in `AGENTS.md` (docs screenshots in the same PR).
7. Locale keys in all four locales (`en`, `fr`, `es`, `uk`); run `bin/dc-run bin/i18n normalize`.

## Anti-patterns that have been tried and rejected

- Rendering the agreement text inline with an always-enabled checkbox (checkout B3 first draft).
- A new modal, drawer or Stimulus controller for one flow.
- Posting acceptance to a custom endpoint or storing it on the order or user directly.
- A different parameter naming scheme for the ticks.
