## Summary

Describe the change and the motivation.

## Evidence Tier

Select one:

- [ ] Docs-only
- [ ] Backend / behavioral
- [ ] UI / workflow

## Evidence Checklist

- [ ] Tests added/updated and passing (`bin/ci`).
- [ ] Lint and security checks (`rubocop`, `brakeman`, `bundler-audit`).
- [ ] Documentation updated under `docs/` describing new/changed functionality.
- [ ] Mermaid diagram source updated under `docs/diagrams/source/` when architecture or workflow changed.
- [ ] Rendered PNGs regenerated with `bin/render_diagrams` and committed.
- [ ] Screenshot spec added or updated under `spec/docs_screenshots/` for UI/workflow changes.
- [ ] Desktop screenshots committed under `docs/screenshots/desktop/` for UI/workflow changes.
- [ ] Mobile screenshots committed under `docs/screenshots/mobile/` for UI/workflow changes.
- [ ] For DB changes, included any needed backfills/dedupes and noted risks.
- [ ] If a normally required evidence type is intentionally omitted, the PR body or a PR comment explains the exemption.

## Access contract

Required when the change touches a policy, scope, role or permission seed, controller authorization, or an API, MCP, job or notifier surface of a record, or adds a private or user-owned model or state. Otherwise write `access contract: unchanged because <reason>`.

- [ ] Subsystem contract in `config/access_contracts/` updated (or created) before the policy code.
- [ ] Probe updated; `spec/access_contract/snapshot.json` regenerated, not hand-edited.
- [ ] Generated tables and decision-tree diagrams regenerated and committed (`better_together:access:docs`, `bin/render_diagrams`).
- [ ] `spec/access_contract` is green; any new deviation or `undecided` cell has a recorded decision.
- [ ] No standing role gains read access to private content or personal data (operate, safety review, disclose stay separate).
- Cells changed / decisions added or closed:
- Surfaces not covered by the probe (views, jobs, serializers, MCP):

## Screenshots / Diagrams

Link the canonical evidence for this PR:

- Docs:
- Changed files:
- Spec / test coverage:
- Diagram source/export:
- Screenshot spec:
- Desktop/mobile screenshots:

## Stakeholder Packet

For significant PRs, add the private Community Engine stakeholder packet links:

- Private page:
- Private post:
- If intentionally deferred, explain why:

## Notes

Anything reviewers should be aware of (migration order, flags, feature toggles).
