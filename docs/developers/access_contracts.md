# How to add or change an access contract entry

The access contract records what access each persona should have to each record, so a policy change cannot silently widen or narrow access. It currently covers communities and people and is being extended to every subsystem. Generated reference pages live in [docs/reference/access_contracts](../reference/access_contracts/README.md).

## When an update is required

Every change that alters an access assumption or its implementation for a subsystem surface updates the contract in the same PR: policies and scopes, role and permission seeds, controller authorization, API, MCP, job and notifier access to a subsystem's records, and any new private, community-scoped, personal or user-created model or state. The PR template has a matching `Access contract` section. A subsystem without a contract gets one when its access is first touched; the planned order is membership requests and invitations, Joatu, comments and posts, events, safety reports, messages, uploads, then API and MCP surfaces.

The `access_contract_guard` CI job (`bin/ci-access-contract-guard`) enforces this on pull requests. It fails when a diff touches `app/policies`, the access control builder, `app/resources`, `app/tools`, or adds or removes `authorize`, `policy_scope` or `skip_authorization` lines in a controller, unless the same diff also touches `config/access_contracts` or `spec/access_contract`, or the PR body has a line `access contract: unchanged because <reason of at least 10 characters>`.

## The three parts

| Part | Where | Role |
| --- | --- | --- |
| Expected | `config/access_contracts/*.yml` | What we decided. One file per subsystem, plus `personas.yml` and `classifications.yml`. |
| Actual | `spec/access_contract/snapshot.json` | What the Pundit policies do, written by `spec/access_contract/probe_spec.rb`. Never edit by hand. |
| Check | `spec/access_contract/drift_spec.rb` | Diffs expected against actual and checks the invariants. |

## Add a resource

1. Add an entry under `resources:` in the subsystem file (or add a new subsystem file and list it in `SUBSYSTEMS` in `lib/better_together/access_contract.rb`). Set `model`, `policy`, `classification`, `states`, `permissions`, `controllers`, and an ordered `rules` list ending in `default_deny`.
2. Describe each action as ordered `rows`. The first row that matches a persona and state wins. A row sets `outcome` (`allow`, `deny`, `conditional`, `undecided`, `na`), a `rule` id from the resource rule list, and a one-line `reason`.
3. Add a probe class for the resource in `spec/support/access_contract/resources.rb` that builds a record for each state and calls every policy action and `Scope#resolve`.
4. Regenerate the snapshot (see below), then run the drift spec until it is green.
5. Regenerate the docs and diagrams and commit them.

## Cell kinds

- `allow` and `deny`: the intended behaviour. If the app disagrees, add `deviation: {actual: allow, actual_rule: <rule id>, decision: CD-n}` and define the decision in the subsystem `decisions:` block with kind `known_deviation`. Do not change the policy in the same change unless that is the point of the PR.
- Any row may carry a short `note` (for example `break-glass pending`); it is appended to the cell's reason in the generated pages.
- `conditional`: depends on a named `condition` and a probe `fixture` value (`allow` or `deny`) the probe produces.
- `undecided`: the intent is not settled. Give `undecided: {actual:, suggests:, decision:}` and a decision of kind `undecided`.
- `na`: the combination cannot occur.

Intent follows the privacy rule: operate, safety review and disclose are separate things, and no standing role reads private content or personal data. Stewards see public content and structure. Community organizers moderate their own private spaces.

## Regenerate

```bash
# Snapshot, after any policy or probe change
bin/dc-run env ACCESS_SNAPSHOT=write bundle exec prspec spec/access_contract/probe_spec.rb

# Docs and diagram sources, then rendered exports
bin/dc-run bash -c 'cd spec/dummy && bin/rails better_together:access:docs'
bin/render_diagrams
```

`better_together:access:check` fails when generated pages are stale, and `better_together:access:verify` prints contract problems, drift and invariant failures.

## What CI checks

`spec/access_contract/drift_spec.rb` fails when:

- the contract is malformed (unknown persona, rule or decision, a missing `default_deny`);
- any cell differs from the snapshot, or a known deviation no longer applies (stale);
- a standing platform role (manager, steward) can read member private or personal data of a non-public record without a recorded deviation;
- a policy matching the subsystem `policy_pattern` has no contract entry or `deferred_policies` reason;
- a routed action of a pilot controller neither calls `authorize` or `policy_scope` nor sits on the `controller_allowlist` with a reason;
- a permission the pilot references is not seeded, not granted to any role (unless listed in `opt_in_permissions`), or not checked in a policy;
- a rule is unused or disagrees with its cells;
- the committed generated docs differ from what the generator produces.

## Limits

Only Pundit is probed. View-level `if` gating, jobs, API serializers, MCP tools and GraphQL are not executed; the inventory lists them and the route scan checks authorization calls statically, but a per-persona result for those surfaces needs its own probe.
