# Block Inventory and Customization

**Target Audience:** Platform organizers and trusted content managers  
**Document Type:** Operator Guide  
**Last Updated:** March 2026

## Overview

Community Engine `0.11.0` ships with a reusable content-block inventory that can be managed at the host level and attached to individual pages. This guide summarizes the current block catalog and the customization surfaces that actually exist on this branch.

For the lower-level model and API details, see:

- [Block System and CMS](../developers/systems/block_system_and_cms.md)
- [Block Management API Guide](../api/block-management-api-guide.md)

## Where organizers manage blocks

Two different UIs matter:

1. `/host/content/blocks` for the reusable host-wide block inventory
2. `/host/pages/:page_id/...` page editing flows for attaching blocks to specific pages

The host inventory is managed by `BetterTogether::Content::BlocksController`. Page attachment flows are managed by `BetterTogether::Content::PageBlocksController`.

Current authorization uses `BetterTogether::Content::BlockPolicy`, so these tools are intended for platform content managers rather than general community members.

## Current block catalog

The current branch exposes the following block types through the API and management layer.

### Editorial and narrative blocks

- `Hero`
- `RichText`
- `Markdown`
- `Html`
- `Css`
- `Template`
- `MermaidDiagram`
- `Image`
- `VideoBlock`
- `QuoteBlock`
- `AlertBlock`
- `AccordionBlock`
- `CallToActionBlock`
- `StatisticsBlock`

### Data-backed and navigational blocks

- `CommunitiesBlock`
- `EventsBlock`
- `PeopleBlock`
- `PostsBlock`
- `ChecklistBlock`
- `NavigationAreaBlock`

## How customization works

### Shared controls

All blocks share a core management surface:

- `identifier`
- `privacy`
- `visible`
- the underlying block type

Display also depends on page-level state such as page privacy and `published_at`, so a valid block can still be hidden if the page is not visible.

### Reusable block records vs page placement

The reusable block inventory and page placement are separate on purpose:

- a block record can exist without being attached to a page
- the same block can be reused on more than one page
- `PageBlock` controls ordering with `position`

This also affects cleanup. Detaching a block from one page does not automatically destroy the underlying block record.

### Localized content

Many block forms and APIs expose locale-specific content fields. In the API layer these appear as keys such as `heading_en`, `content_fr`, or `caption_es`. In the host UI, the same translated content is surfaced through the block forms for block types that define localized attributes.

### Block-specific settings

Different blocks expose different configuration fields. Examples from the current implementation include:

- accordion items and open-first behavior
- alert level and dismissibility
- CTA labels and URLs
- checklist, navigation area, or resource references
- statistics JSON, media settings, and template paths

The complete writable attribute surface is enforced by each block class and reflected in `BlockResource` and the MCP block tools.

## Recommended organizer workflow

1. create or update the reusable block in `/host/content/blocks`
2. attach it to the relevant page through the page editing flow
3. verify block order and page visibility
4. use the JSON:API or MCP tools only when you need scripted or remote management

## What this branch does not add

This branch does not introduce a separate visual block marketplace or a separate admin-only CMS database. The same `Content::Block` and `PageBlock` records are used by:

- the host UI
- the page editing flow
- JSON:API block endpoints
- the block-focused MCP tools

For implementation completeness tracking by block type, see the existing [Content Block Type Completeness Checklist](../content-block-completeness-checklist.md).
