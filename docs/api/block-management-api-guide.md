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

## Inputs for headless publishers

These fields let a script publish a complete page or post without a browser. Send `block_type` before the image fields.

| Where | Field | Notes |
|---|---|---|
| Image block | `media_data`, `media_filename` | Base64 JPEG, PNG or WebP (5 MB). The type is taken from the bytes. A caption is required. Write-only. |
| Hero block | `background_image_data`, `background_image_filename` | Same rules. Replaces the background on update. Write-only. |
| Image block | `attribution_url_en` (and `_fr`, `_es`, `_uk`) | Link the attribution text points to. |
| Page, post | `category_identifiers` | Array of category identifiers. Unknown identifiers return 422. |
| Page | `slug` | Forward slashes are kept (`ships/mt-explora-iii`); each segment is parameterized. |
| Post | `created_at` (create only), `updated_at` | Keep original dates for imports. `updated_at` is re-applied after commit because saving blocks or a cover touches the record. |

Every API request runs in the default locale. Send `X-Api-Locale: fr` to write another locale; a locale left on the server thread by a web request is ignored.

### Attaching blocks to posts and keeping them on update

`attachment_block_ids` (write-only, create and update) names existing blocks that are attached at the top of a post's body in that order. A host app opts a block class in with `BetterTogether::ContentSecurity::AttachableRegistry.register('Your::BlockClass')`; the class must include `ActionText::Attachable` and provide its attachment partial. Only registered classes of the post's platform are accepted (`422` otherwise), and a registered block is rendered only while it is public and visible.

A body update keeps the post's blocks: `PATCH` with new `content` and no attachments puts the existing attachments back in front of the new text, so a publisher can rewrite the text without re-sending the blocks. Sending `attachment_block_ids` on update replaces them. Sending rendered `<action-text-attachment>` HTML back as `content` is rejected, because it has no signed id.

### Event inputs for publishers

`events` accepts the same publisher inputs, on create and update:

- `hosts` (a list, or a JSON string of `[{"host_type": "BetterTogether::Community", "host_id": "..."}]`) sets every host of the event, of any `HostsEvents` type. It replaces the list, so the creator is not added as a host when it is given. As in the event form, a host must be the person or a community they can host for (`valid_event_host_ids`); platform managers may name any host (`422` otherwise).
- `status` sets the lifecycle status (`draft`, `confirmed`, `cancelled`); an unknown value is `422`.
- `cover_image_data` (base64) with optional `cover_image_filename` sets the cover image. Neither is returned.
- `address_spec` (write-only; a hash or a JSON string) locates the event at a street address: `line1` is required, with optional `line2`, `city_name`, `state_province_name`, `postal_code`, `country_name` and a `name` for the place. An existing address with the same line1, city, postal code and country is reused, otherwise a public one is created. Blank clears the location. A named place prints its street address too ("Rotary Arts Centre, 5 Park Street, ...") on cards, pages and map popups.
- `attachment_block_ids` appends existing blocks to the end of the description, under the text, in that order. A block already in the description is not added twice, so sending the same ids again changes nothing. The registry and platform rules above apply.

### Navigation landmarks in HTML blocks

HTML block content is sanitized. `nav` and the accessibility attributes `aria-label`, `aria-labelledby`, `aria-current` and `aria-hidden` are kept, so a breadcrumb can be a labelled `<nav aria-label="Breadcrumb">` with `aria-current="page"` on the current item. Scripts, event handlers and unsafe link protocols are still removed.
