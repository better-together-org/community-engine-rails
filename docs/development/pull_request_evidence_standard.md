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
- explicit screenshot exemption note when no UI workflow changed

### Backend / Behavioral

Use this tier when the PR changes application behavior without changing a canonical user-facing workflow.

Required:

- targeted automated tests
- updated documentation under `docs/`
- a system or architecture diagram when the change affects a meaningful flow or data boundary
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
