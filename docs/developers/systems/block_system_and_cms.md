# Block System and CMS

This guide documents the current `0.11.0` block-management surface in Community Engine. It complements the broader [Content Management System](content_management.md) guide by focusing on the concrete block model, JSON:API endpoints, and MCP tools that exist on this branch.

## What exists in this release lane

The CMS block system is built around three layers:

1. `BetterTogether::Content::Block` and its STI subclasses for reusable content blocks
2. `BetterTogether::Content::PageBlock` for ordered page-to-block attachment
3. host and page management surfaces for creating, attaching, updating, detaching, and deleting blocks

Relevant code paths:

- `app/models/better_together/content/block.rb`
- `app/models/better_together/content/page_block.rb`
- `app/controllers/better_together/content/blocks_controller.rb`
- `app/controllers/better_together/content/page_blocks_controller.rb`
- `app/controllers/better_together/api/v1/blocks_controller.rb`
- `app/controllers/better_together/api/v1/page_blocks_controller.rb`
- `app/resources/better_together/api/v1/block_resource.rb`
- `app/resources/better_together/api/v1/page_block_resource.rb`
- `app/tools/better_together/mcp/*block*_tool.rb`

## Block hierarchy

`BlockResource` exposes the engine's current block catalog polymorphically. The concrete block types wired into the API layer on this branch are:

- `AccordionBlock`
- `AlertBlock`
- `CallToActionBlock`
- `ChecklistBlock`
- `CommunitiesBlock`
- `Css`
- `EventsBlock`
- `Hero`
- `Html`
- `Image`
- `Markdown`
- `MermaidDiagram`
- `NavigationAreaBlock`
- `PeopleBlock`
- `PostsBlock`
- `QuoteBlock`
- `RichText`
- `StatisticsBlock`
- `Template`
- `VideoBlock`

See also:

- [content-block-completeness checklist](../../content-block-completeness-checklist.md)
- [block resource hierarchy diagram](../../diagrams/source/blockresource_hierarchy_and_types.mmd)

## Data model

### `BetterTogether::Content::Block`

The base block model stores shared CMS fields:

- `identifier`
- `privacy`
- `visible`
- `protected`
- `type` for STI dispatch
- JSON-backed configuration in fields such as `content_data`, `css_settings`, `media_settings`, and related settings columns

`BlockResource` exposes `type` as `block_type` to avoid JSON:API reserved-word conflicts. It also flattens block-specific Storext attributes and locale-suffixed translated attributes into one API surface.

### `BetterTogether::Content::PageBlock`

`PageBlock` is the ordered join between a page and a block. It is the authoritative place for:

- page attachment
- display order via `position`
- detach operations that leave the underlying block reusable

This matters because creating a block record does not automatically place it on a page unless the caller uses a page-aware path such as `PageBlocksController`, `PageBlockResource`, or the page-oriented MCP tools.

## Management surfaces

### Host UI

Platform-level content managers have a host inventory at:

- `/host/content/blocks`

The host UI can create, edit, inspect, and delete reusable block records through `BetterTogether::Content::BlocksController`.

Authorization is handled by `BetterTogether::Content::BlockPolicy`, which currently allows management only for users with `manage_platform_settings` or `manage_platform`.

### Page builder UI

Page-specific block attachment flows run through:

- `/host/pages/:page_id/page_blocks/new`
- `/host/pages/:page_id/page_blocks/:id`

`BetterTogether::Content::PageBlocksController` builds a new `PageBlock`, initializes the requested block type, and returns Turbo Stream form fragments for page editing.

### JSON:API

Two JSON:API resources are part of the public API namespace:

- `blocks`
- `page_blocks`

Use `blocks` for block records and `page_blocks` for page attachment and ordering. The dedicated [Block Management API Guide](../../api/block-management-api-guide.md) covers the request patterns.

### MCP tools

Block management also has a dedicated MCP tool set:

- `list_page_blocks`
- `get_block`
- `create_page_block`
- `update_block`
- `delete_page_block`

These tools are implemented under `app/tools/better_together/mcp/` and are tagged `:authenticated`, so they are only exposed when the current MCP request resolves to an authenticated user context. The server-level filtering lives in `config/initializers/fast_mcp.rb`.

## CRUD and attachment model

The current block lifecycle is intentionally split:

1. create or update a reusable block record
2. attach it to a page through `PageBlock`
3. reorder or detach the `PageBlock`
4. optionally destroy the underlying block when it is no longer attached elsewhere

Two details are easy to miss:

- `PageBlockResource#_remove` uses SQL `delete`, not Active Record `destroy`, so detaching a block does not cascade into block deletion.
- `DeletePageBlockTool` can delete the block record too, but only when it is no longer attached to other pages.

See:

- [block CRUD and management flow](../../diagrams/source/block_crud_and_management_flow.mmd)

## Localization and block-specific attributes

`BlockResource` exposes locale-suffixed translated attributes for `en`, `fr`, `es`, and `uk`, including fields such as:

- `heading_en`
- `content_fr`
- `caption_es`
- `diagram_source_uk`

It also exposes guarded block-specific attributes such as:

- `accordion_items_json`
- `alert_level`
- `video_url`
- `stats_json`
- `navigation_area_id`
- `template_path`
- `markdown_file_path`
- `html_content`
- `cta_url`

The exact writable attribute set depends on the block class. `create_page_block_tool.rb`, `update_block_tool.rb`, and `BlockResource` all use the block class's permitted/localized attribute lists rather than allowing arbitrary keys.

## What is not in scope here

This release slice includes block JSON:API coverage and MCP tooling, but it does not add a separate admin framework or a different CMS storage model. The same `Content::Block` and `PageBlock` models back the host UI, the API, and the MCP tools.

For page publishing, page visibility, and cache behavior beyond block CRUD, see [Content Management System](content_management.md).
