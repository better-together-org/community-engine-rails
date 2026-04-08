# Pull Request Evidence Standard

## Purpose

Community Engine pull requests should be understandable and reviewable by technical and non-technical stakeholders without requiring hidden local context.

This standard defines the minimum documentation evidence expected for each PR tier.

## Evidence Tiers

### Docs-only

Use this tier when the PR changes documentation or diagrams only.

Required:

- markdown updates under `docs/`
- Mermaid source updates under `docs/diagrams/source/` when diagrams change
- rendered PNG and SVG exports under `docs/diagrams/exports/`
- PR body links to the key changed files
- PR body notes the validation and spec coverage used for review
- explicit screenshot exemption note when no UI workflow changed

### Backend / Behavioral

Use this tier when the PR changes application behavior without changing a canonical user-facing workflow.

Required:

- targeted automated tests
- updated documentation under `docs/`
- a system or architecture diagram when the change affects a meaningful flow or data boundary
- PR body links to the key changed files
- PR body calls out the targeted spec/test coverage used for review
- explicit screenshot exemption note when screenshots are not applicable

### UI / Workflow

Use this tier when the PR changes a canonical user-facing interface or workflow.

Required:

- targeted automated tests
- updated documentation under `docs/`
- Mermaid flow diagram source plus rendered exports
- docs screenshot spec under `spec/docs_screenshots/`
- desktop screenshots under `docs/screenshots/desktop/`
- mobile screenshots under `docs/screenshots/mobile/`
- PR body links to the key changed files
- PR body links to screenshot, diagram, and spec coverage artifacts explicitly

Quality rules for UI screenshots:

- annotations and callouts must not cover the UI element or container being reviewed when surrounding whitespace is available
- when the highlighted selector is only part of a larger card, panel, or toolbar, the screenshot spec should provide a broader container-avoidance selector so callout placement protects the whole component
- generated screenshots should be visually spot-checked before PR publication to confirm that callouts, overlays, and labels do not hide the evidence they are supposed to explain

## Significant PR Packet Rule

Significant PRs should also have a private Community Engine stakeholder packet:

- one private page as the canonical packet
- one private post for updates and discussion

The packet should summarize the change, diagrams, screenshots, validation, risks, and deferred items.

## Automation

Community Engine enforces the structural portion of this standard through:

- `.github/pull_request_template.md`
- `scripts/validate_pr_evidence.sh`
- the `pr_evidence` CI job in `.github/workflows/rubyonrails.yml`

The validator checks that the required evidence file groups are present in the diff for the inferred PR tier. It does not replace human review of evidence quality.

For pull requests, the PR body should remain the canonical GitHub review packet. At minimum it should contain:

- `## Summary`
- `## Evidence Tier`
- `## Screenshots / Diagrams`

The `Screenshots / Diagrams` section should include direct reviewer-facing links or paths for:

- changed files
- spec / test coverage
- diagram source and rendered exports
- screenshot specs and generated screenshots
