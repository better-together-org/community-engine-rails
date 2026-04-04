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

Those helpers write back into the canonical `selector` field rather than introducing separate hidden schema, so the persisted selector remains auditable and transportable across exports.

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
