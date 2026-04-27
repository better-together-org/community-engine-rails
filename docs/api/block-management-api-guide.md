# Block Management API Guide

This guide documents the block-management API surface that currently exists in Community Engine `0.11.0`.

## Scope

There are two JSON:API resources involved in block management:

- `blocks` for the reusable `BetterTogether::Content::Block` records
- `page_blocks` for the ordered page-to-block join records

Routes are declared in `config/routes/api_v1.rb`:

- `jsonapi_resources :blocks`
- `jsonapi_resources :page_blocks`

Relevant implementation:

- `app/controllers/better_together/api/v1/blocks_controller.rb`
- `app/controllers/better_together/api/v1/page_blocks_controller.rb`
- `app/resources/better_together/api/v1/block_resource.rb`
- `app/resources/better_together/api/v1/page_block_resource.rb`

## Authentication and authorization

Both controllers inherit from `BetterTogether::Api::ApplicationController`, and block access is authorized through `BetterTogether::Content::BlockPolicy`. In practice, write access is intended for platform content managers.

For AI-agent access, these same block operations are also available through the MCP tools documented in [MCP Integration Guide](mcp-integration-guide.md) and summarized below.

## `blocks` resource

### Supported operations

- `GET /api/v1/blocks`
- `GET /api/v1/blocks/:id`
- `POST /api/v1/blocks`
- `PATCH /api/v1/blocks/:id`
- `DELETE /api/v1/blocks/:id`

### Filters

`BlockResource` currently supports:

- `filter[block_type]`
- `filter[privacy]`
- `filter[identifier]`
- `filter[page_id]`

Examples:

```http
GET /api/v1/blocks?filter[page_id]=PAGE_UUID
GET /api/v1/blocks?filter[block_type]=BetterTogether::Content::AccordionBlock
GET /api/v1/blocks?filter[identifier]=homepage-hero
```

### Key attributes

`BlockResource` exposes:

- `block_type` instead of raw STI `type`
- shared fields such as `identifier`, `privacy`, `visible`, and `protected`
- block-specific Storext attributes such as `video_url`, `accordion_items_json`, `stats_json`, and `navigation_area_id`
- translated fields with locale suffixes for `en`, `fr`, `es`, and `uk`

Examples of localized keys:

- `heading_en`
- `content_fr`
- `caption_es`
- `diagram_source_uk`

### Create example

Creating a block record does not attach it to a page. Use `page_blocks` for attachment.

```json
{
  "data": {
    "type": "blocks",
    "attributes": {
      "block_type": "BetterTogether::Content::AlertBlock",
      "identifier": "homepage-alert",
      "privacy": "public",
      "visible": true,
      "heading_en": "Important update",
      "body_text": "Doors open at 7pm.",
      "alert_level": "info",
      "dismissible": true
    }
  }
}
```

### Update example

`block_type` is creatable but not updatable. After creation, update only the block's mutable attributes.

```json
{
  "data": {
    "type": "blocks",
    "id": "BLOCK_UUID",
    "attributes": {
      "heading_en": "Updated heading",
      "visible": false
    }
  }
}
```

## `page_blocks` resource

### Supported operations

- `GET /api/v1/page_blocks`
- `GET /api/v1/page_blocks/:id`
- `POST /api/v1/page_blocks`
- `PATCH /api/v1/page_blocks/:id`
- `DELETE /api/v1/page_blocks/:id`

### Purpose

`PageBlockResource` manages the ordered join between a page and a block:

- attach a block to a page
- set or update `position`
- detach a block without deleting the block record

`DELETE /api/v1/page_blocks/:id` is intentionally a detach operation. `PageBlockResource#_remove` uses SQL `delete` so the block itself is not destroyed as a side effect.

### Create example

```json
{
  "data": {
    "type": "page_blocks",
    "attributes": {
      "position": 0
    },
    "relationships": {
      "page": {
        "data": { "type": "pages", "id": "PAGE_UUID" }
      },
      "block": {
        "data": { "type": "blocks", "id": "BLOCK_UUID" }
      }
    }
  }
}
```

### Reorder example

```json
{
  "data": {
    "type": "page_blocks",
    "id": "PAGE_BLOCK_UUID",
    "attributes": {
      "position": 3
    }
  }
}
```

## MCP block tools

For AI-assisted content management, the engine also exposes page-oriented block tools:

- `list_page_blocks`
- `get_block`
- `create_page_block`
- `update_block`
- `delete_page_block`

These tools wrap the same models and policies, but they provide a task-oriented interface:

- `create_page_block` both creates the block and attaches it to a page
- `delete_page_block` detaches first and optionally destroys the block if it is unused elsewhere
- `list_page_blocks` returns page order and block summaries without requiring separate join queries

Relevant code:

- `app/tools/better_together/mcp/create_page_block_tool.rb`
- `app/tools/better_together/mcp/update_block_tool.rb`
- `app/tools/better_together/mcp/delete_page_block_tool.rb`
- `app/tools/better_together/mcp/list_page_blocks_tool.rb`
- `app/tools/better_together/mcp/get_block_tool.rb`

## Practical guidance

- Use `blocks` when you need canonical block CRUD or filtering by type, identifier, or page.
- Use `page_blocks` when you need to attach, detach, or reorder blocks on a page.
- Use MCP tools when an authenticated AI assistant needs the higher-level page editing workflow.

For the system-level model behind these endpoints, see [Block System and CMS](../developers/systems/block_system_and_cms.md).
