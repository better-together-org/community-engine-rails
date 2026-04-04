# Citation and Evidence Chain System

## Purpose

Community Engine needs a citation system that does more than format bibliography text. The platform must support:

- structured source metadata
- auditable attribution and provenance
- export to MLA, APA, and future cooperative governance styles
- citation of nontraditional evidence, including oral history, images, stories, art, policy, and community testimony
- accessible evidence rendering in published pages and posts
- selector-aware evidence targeting across rich text, content blocks, and other publishable records

This system separates three concerns:

1. `Citation metadata`
2. `Display/export formatting`
3. `Claim-to-evidence and provenance linking`

The first two were implemented first. PR `#1494` now adds the first schema-backed claim layer as well.

## Current Implementation

### Review assets

- [Mermaid Source](../../diagrams/source/pr_1494_claim_evidence_browser_flow.mmd)
- [PNG Export](../../diagrams/exports/png/pr_1494_claim_evidence_browser_flow.png)
- [SVG Export](../../diagrams/exports/svg/pr_1494_claim_evidence_browser_flow.svg)
- [Desktop Screenshot](../../screenshots/desktop/claim_evidence_browser.png)
- [Mobile Screenshot](../../screenshots/mobile/claim_evidence_browser.png)
- [Citation Import Flow Source](../../diagrams/source/pr_1494_citation_import_flow.mmd)
- [Citation Import Flow PNG](../../diagrams/exports/png/pr_1494_citation_import_flow.png)
- [Citation Import Flow SVG](../../diagrams/exports/svg/pr_1494_citation_import_flow.svg)
- [Citation Import Desktop Screenshot](../../screenshots/desktop/citation_import_browser.png)
- [Citation Import Mobile Screenshot](../../screenshots/mobile/citation_import_browser.png)
- [GitHub Citation Import Flow Source](../../diagrams/source/pr_1494_github_citation_import_flow.mmd)
- [GitHub Citation Import Flow PNG](../../diagrams/exports/png/pr_1494_github_citation_import_flow.png)
- [GitHub Citation Import Flow SVG](../../diagrams/exports/svg/pr_1494_github_citation_import_flow.svg)
- [GitHub Citation Import Desktop Screenshot](../../screenshots/desktop/github_citation_import_browser.png)
- [GitHub Citation Import Mobile Screenshot](../../screenshots/mobile/github_citation_import_browser.png)

### Structured citations

`BetterTogether::Citation` is a polymorphic record that can attach to:

- `BetterTogether::Page`
- `BetterTogether::Post`
- `BetterTogether::Event`
- `BetterTogether::CallForInterest`
- `BetterTogether::Agreement`
- `BetterTogether::Calendar`
- `BetterTogether::Joatu::Request`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Agreement`
- `BetterTogether::Authorship`

Each citation currently stores:

- `reference_key`
- `source_kind`
- `title`
- `source_author`
- `publisher`
- `source_url`
- `locator`
- `published_on`
- `accessed_on`
- `excerpt`
- `rights_notes`
- `metadata`

This gives CE a normalized, auditable citation record instead of a freeform footnote string.

### Citeable records

The `BetterTogether::Citable` concern adds:

- polymorphic `citations`
- nested attribute support for forms
- bibliography helper methods

It is currently included in:

- `BetterTogether::Page`
- `BetterTogether::Post`
- `BetterTogether::Event`
- `BetterTogether::CallForInterest`
- `BetterTogether::Agreement`
- `BetterTogether::Calendar`
- `BetterTogether::Joatu::Request`
- `BetterTogether::Joatu::Offer`
- `BetterTogether::Joatu::Agreement`
- `BetterTogether::Authorship`

### Publishing UI

Page, post, event, call-for-interest, agreement, calendar, and JOATU exchange forms now expose a `Citations and Evidence` section. That lets editors enter structured evidence metadata directly on the record being published or governed.

### Rendering

Pages, posts, events, calls for interest, agreements, calendars, and JOATU exchanges now render an `Evidence and Citations` bibliography section when citations are present.

### Claims and evidence links

`BetterTogether::Claim` and `BetterTogether::EvidenceLink` now provide the first explicit evidence graph layer.

A claim records:

- `claim_key`
- `statement`
- `selector`
- `review_status`

An evidence link records:

- `relation_type`
- `citation`
- `locator`
- `quoted_text`
- `editor_note`
- `review_status`

This allows one page or post to store several explicit assertions and connect each one to one or more citations with typed relationships like `supports` or `contests`.

### Block-level selector support

Rendered content blocks now expose stable evidence target metadata through the shared block wrapper.

Each rendered block includes:

- `id` based on `dom_id(block)`
- `data-citation-target`
- `data-evidence-selector`
- `data-block-type`

The current selector convention is:

- `block:<block_name>:<identifier-or-id>`

This gives claims and future editor tooling a stable way to point at markdown, rich text, alert, hero, image, statistics, and other block-based content without patching each block partial independently.

For media-capable blocks, selector suggestions now go further than the base block anchor:

- image blocks suggest selectors for:
  - the media asset
  - caption
  - alt text
  - region-based annotation placeholders
- video blocks suggest selectors for:
  - the embedded video
  - caption
  - timestamp-based annotation placeholders

Claim entry forms now also include selector helpers for the two most common media-specific cases:

- exact video timestamps, normalized to `HH:MM:SS`
- image regions using `x/y/w/h` coordinates
- suggested selector presets for record, rich text, and block/media targets

Those helpers write back into the canonical `selector` field rather than introducing separate hidden schema, so the persisted selector remains auditable and transportable across exports.

### Evidence picker expansion

Evidence link forms no longer only expose citations created directly on the current record.

The picker now groups available citations by evidence source, including:

- `Current record`
- linked contribution records such as review, editing, or authorship contribution entries that carry their own citations

This gives claim reviewers a first evidence browser for pulling in supporting material that was attached to adjacent contribution records without duplicating citation data immediately.

The claim evidence form now also renders a browseable source panel for each evidence link. Reviewers can inspect grouped citations, preview locators and excerpts, and apply a citation into the current evidence link with one action. When available, locator and excerpt values are copied into the evidence link as drafting defaults.

That browser now includes lightweight filters for:

- source origin
- record type
- contribution role
- contribution type

This keeps the first cross-record evidence browser usable even when a publishing record is linked to several contribution records with overlapping citation inventories.

### Selector-aware Trix integration

The rich text toolbar now includes a `Citation` action modeled on the existing Trix link dialog flow.

The current dialog now supports:

- citation selection from structured record-local citation options
- optional locator entry
- selector metadata selection
- exact selected-text range capture using `trix-range:<start>:<end>`

When text is selected before opening the dialog, the editor restores that selection and inserts the citation around it, attaching a stable `data-evidence-selector` attribute when available.

This is still intentionally incremental. It does not yet provide a full claim picker or source browser, but it now bridges:

- exact rich-text span targeting
- stable block selector targeting
- media-aware selector suggestions for image and video blocks
- bibliography-backed inline citation references

Inline Trix citations intentionally remain record-local for now. That preserves correct bibliography anchors in published rich text. Cross-record evidence browsing is currently implemented in claim evidence workflows, where linked citations can be referenced without silently importing or duplicating them into the publishing record.

To bridge that gap safely, citation field forms now include an explicit `Import Linked Citation Into This Record` panel. Editors can review linked contribution citations and copy one into the current record's own citation rows. This makes the duplication deliberate, visible, and auditable instead of implicit.

Imported citation copies now also store audit metadata in the local citation record. The copied citation can record:

- source citation id
- source citation key
- source record label
- source record type

That provenance is rendered in the bibliography so readers and reviewers can tell when a local citation entry originated from a linked contribution record rather than being authored directly on the current record.

### GitHub-native citation import

Linked GitHub identities can now provide importable citation candidates directly inside the citation form.

The import flow uses a dedicated authenticated endpoint and a small catalog service:

- `BetterTogether::GithubCitationImportsController`
- `BetterTogether::GithubCitationImportCatalog`

This keeps the existing citation model intact. GitHub repositories, pull requests, issues, and commits are normalized into ordinary `BetterTogether::Citation` field values before they are saved on the current record.

The current import path is intentionally local-bibliography-first:

1. load GitHub source candidates from a linked identity
2. choose a repository, pull request, issue, or commit source
3. import it into a local citation row on the current record
4. save it as part of that record's own bibliography

That preserves:

- local inline Trix citation anchors
- local evidence picker behavior
- bundle / CSL / MLA / APA export consistency
- explicit provenance for imported copies

GitHub-native metadata is stored in citation `metadata` and can include:

- `repository_name`
- `repository_path`
- `pull_request_number`
- `issue_number`
- `commit_sha`
- `github_handle`

This gives the platform a reusable path for evidence import from code-hosting systems without inventing a parallel GitHub-only evidence schema.

### Export surface

The first machine-readable citation export surface now exists through `CitationExportsController`.

Supported export styles:

- `csl`
- `apa`
- `mla`

The current public route shape is:

- `/citations/export/:citeable_key/:id?style=csl`

The exportable citeable keys currently include:

- `page`
- `post`
- `event`
- `call_for_interest`
- `agreement`
- `calendar`
- `joatu_request`
- `joatu_offer`
- `joatu_agreement`

`csl` currently returns normalized CSL-style JSON generated from structured citation metadata. `apa` and `mla` return line-oriented plain text derived from the same source data instead of storing style-specific bibliography strings as primary records.

The CSL export now includes richer cooperative-governance metadata where available through `Citation#metadata`, including:

- container or archive titles
- editor lists
- version and record numbers
- archive locations
- medium and genre
- jurisdiction
- keyword lists

This keeps the primary citation record style-agnostic while giving downstream tools enough structure to generate more faithful MLA, APA, CSL, and governance-oriented exports later.

Provenance-aware export is now optional rather than implicit. When `include_provenance=true` is supplied to the export route, imported citation copies append their linked-source provenance to the exported CSL note field and to line-oriented APA or MLA output. Default exports remain clean and citation-style focused.

### Contribution evidence summaries

Imported citation provenance is also surfaced outside full bibliography views.

Contributed page and post cards now render a shared record evidence summary that shows:

- claim count
- citation count
- imported citation count
- direct download links for:
  - governance bundle export
  - CSL export

That summary appears anywhere those shared card partials are rendered, including person profile contribution tabs. This gives contributors and reviewers a compact view of evidence density and imported-source reliance before opening the full record.

Additional review assets for this slice:

- [Contribution Evidence Summary Flow Source](../../diagrams/source/pr_1494_contribution_evidence_summary_flow.mmd)
- [Contribution Evidence Summary PNG](../../diagrams/exports/png/pr_1494_contribution_evidence_summary_flow.png)
- [Contribution Evidence Summary SVG](../../diagrams/exports/svg/pr_1494_contribution_evidence_summary_flow.svg)
- [Contribution Evidence Summary Desktop Screenshot](../../screenshots/desktop/contribution_evidence_summary.png)
- [Contribution Evidence Summary Mobile Screenshot](../../screenshots/mobile/contribution_evidence_summary.png)

### Community-facing evidence and governance bundles

The same shared evidence summary now appears on event cards, which means community event listings inherit evidence density and imported-citation visibility without needing a community-specific evidence renderer.

The citation export endpoint also now supports a governance review packet mode:

- `style=bundle`

That bundle returns:

- citeable record metadata
- summary counts for citations, imported citations, claims, and contributions
- CSL-style citation payloads
- claim and evidence-link structures
- linked contribution summaries
- linked GitHub identity metadata for contributors when local GitHub OAuth integrations exist

This gives reviewers a single machine-readable export that can be used for cooperative governance review, audit trails, or downstream packaging without flattening everything into one text bibliography.

Additional review assets for this slice:

- [Governance Bundle and Community Evidence Flow Source](../../diagrams/source/pr_1494_governance_bundle_and_community_evidence_flow.mmd)
- [Governance Bundle and Community Evidence PNG](../../diagrams/exports/png/pr_1494_governance_bundle_and_community_evidence_flow.png)
- [Governance Bundle and Community Evidence SVG](../../diagrams/exports/svg/pr_1494_governance_bundle_and_community_evidence_flow.svg)
- [Community Event Evidence Summary Desktop Screenshot](../../screenshots/desktop/community_event_evidence_summary.png)
- [Community Event Evidence Summary Mobile Screenshot](../../screenshots/mobile/community_event_evidence_summary.png)

### Cross-record evidence exports

The shared governance export links are no longer limited to page, post, and event surfaces. They now appear across the other evidence-bearing record types that already render claims and bibliography sections, including:

- JOATU requests
- JOATU offers
- JOATU agreements
- agreements
- calendars

The governance bundle payload also now preserves raw GitHub-native citation metadata for repository and pull-request style sources. This keeps the normalized CSL rendering while also exposing repository paths, pull request numbers, and commit identifiers in the audit packet when that information exists locally in citation metadata.

Additional review assets for this slice:

- [Cross-record Evidence Exports Flow Source](../../diagrams/source/pr_1494_cross_record_evidence_exports_flow.mmd)
- [Cross-record Evidence Exports PNG](../../diagrams/exports/png/pr_1494_cross_record_evidence_exports_flow.png)
- [Cross-record Evidence Exports SVG](../../diagrams/exports/svg/pr_1494_cross_record_evidence_exports_flow.svg)
- [JOATU Evidence Bundle Links Desktop Screenshot](../../screenshots/desktop/joatu_evidence_bundle_links.png)
- [JOATU Evidence Bundle Links Mobile Screenshot](../../screenshots/mobile/joatu_evidence_bundle_links.png)

## Standards Direction

The current metadata layer is designed to grow toward standards-compatible export and provenance.

### Citation formatting

The platform should store richer normalized metadata than any single style requires, then render style-specific output later.

Current export helpers:

- `apa_citation`
- `mla_citation`
- `to_csl_json`

Future export targets should be driven from normalized source metadata rather than storing style-specific strings as the source of truth.

Recommended compatibility targets:

- CSL JSON for citation/export interoperability
- DCMI / Dublin Core terms for descriptive metadata interoperability
- DataCite relation modeling for related identifiers and source graphs

### Provenance and evidence chains

The citation table is not the final provenance system. We still need a graph of:

- `Claim`
- `EvidenceLink`
- `ProvenanceEvent`
- `Agent`
- `Source`

That later phase should support:

- one claim supported by multiple sources
- one source supporting multiple claims
- derivation chains
- editorial review state
- citation selectors and locators
- rights and consent metadata for sensitive sources

Recommended conceptual standards for that phase:

- W3C PROV-O for provenance
- W3C Web Annotation for claim/selector links
- PREMIS-style event logging for preservation/audit events
- DataCite relation types for source graph relationships

## Nontraditional Evidence

The system must treat the following as first-class evidence types, not miscellaneous edge cases:

- oral history
- interviews
- community testimony
- stories
- artwork
- images
- policies and governance documents
- repositories, issues, and pull requests
- surveys and other community research outputs

This means future source metadata must support:

- consent and access restrictions
- narrator/interviewer or storyteller/collector roles
- repository or holding institution
- rights and reuse context
- community protocol notes
- locators like page, timestamp, figure, paragraph, slide, or commit SHA

## Known Limits

The current slice does **not** yet implement:

- automatic style switching in published views
- importer/exporter support for CSL JSON, BibTeX, RIS, or JSON-LD
- citation-aware moderation or review workflows
- global picker-backed citation browsing across records
- conversion between footnotes, endnotes, and bibliography-only references

## Next Steps

1. Add richer claim selectors for images, media timestamps, and cross-record evidence targets beyond the current `trix-range` and block selector support.
2. Add export/import mapping for CSL JSON and related open citation formats.
3. Add citation picker dialogs to Trix so editors choose existing evidence records instead of typing keys manually.
4. Extend citation rendering to governance records and contribution histories.
5. Add provenance events and source-graph relations for derivation, supersession, and custody history.
