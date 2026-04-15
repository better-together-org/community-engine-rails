# Agreement Management

Community Engine ships agreements as reusable governance tools, not just legal boilerplate. Platform organizers should treat the seeded agreements as starter infrastructure that can be adapted, activated, or retired with intent.

## Agreement Types

- `policy_consent`
  Used for agreements required to create and keep an account in good standing, such as Terms of Service, Privacy Policy, and Code of Conduct.
- `publishing_consent`
  Used for agreements required before a person can make content public, such as the content publishing agreement.
- `transactional_agreement`
  Used for exchange records like mutual aid agreements between an offer and a request.

## Lifecycle

Each agreement now has a lifecycle state:

- `draft`
  Internal work in progress. Draft agreements do not drive consent collection.
- `active`
  Used in live participant flows and the agreement center.
- `retired`
  No longer collects new acceptance, but remains part of acceptance history.

Use `active_for_consent` together with `lifecycle_state` to decide whether an agreement is actually enforced.

## Re-Consent

When an active agreement changes materially:

1. Update the agreement content or linked page.
2. Turn on `Require participants to review updates again`.
3. Add a short `What changed?` summary.

Community Engine stores an immutable content digest and title snapshot at the moment of acceptance. When re-consent is required and the content digest changes, prior acceptance becomes stale and the agreement center will ask participants to review it again.

## Default Flows

- Registration agreements should use `required_for: registration`.
- The content publishing agreement should use `required_for: first_publish`.
- Mutual aid agreements should remain transactional and be accepted in context, not added to account sign-up.

## Operator Practice

- Keep seeded agreements engine-neutral and specific to the practice you want new platforms to inherit.
- Prefer linked pages for long-form community-readable agreement text.
- Use structured agreement terms as fallback clauses and for internal editing discipline.
- Retire outdated agreements instead of deleting them when participants may already have accepted them.
