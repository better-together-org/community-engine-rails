# Model Concerns Reference (0.11.0 additions and changes)

Short reference for the model concerns that are new or changed in 0.11.0 and are not covered by a system page. Each entry says what it adds, where it is included, and what to know before using it. Concerns that belong to a system are described there and linked.

Files live under `app/models/concerns/better_together/` unless noted.

## Privacy and platform scoping

### `PrivacyCeilingValidatable`

Validates that a record's `privacy` does not exceed the ceiling set by its platform and community. Ceiling order is `private`, `community`, `public`.

| Platform | Community | Ceiling |
|---|---|---|
| public | public (or none) | `public` |
| public | not public | `community` |
| not public | any | `community` |

A non-public platform or community caps content at `community`, not `private`, because members of a locked-down space can still write community-scoped content. The check runs only for new records and when `privacy` changes, so existing records stay valid. An external wrapping platform (`external?`) has no ceiling.

**Exemptions.** `privacy_ceiling_exempt?` returns `federated_mirror_privacy_ceiling_exempt?` (a federated mirror carries its origin's already-vetted privacy). Models override it for visibility that is governed elsewhere: `Platform`, `Agreement`, `Page`, `Category`, `NavigationItem` and `Content::Block` define their own. Seeded pages set `seed_privacy_ceiling_exempt` so built-in pages can be public on a private platform. Host models that own a private placeholder community (for example a venue) need `privacy_ceiling_exempt?` to create public records; see the [host upgrade guide](../releases/0.11.0_host_upgrade_guide.md).

### `CommunityAssignable`

Before validation, assigns the platform's community when the record has a `community_id` and none is set (`community ||= platform&.community`). Include it in platform-scoped records that belong to a community.

### `PrimaryFlag`

Adds a boolean `primary_flag` that must be unique among records, or among records sharing a parent when the model calls `primary_flag_scope(:parent_id)` (with `allow_blank: true` to allow records without a parent). Class helpers: `primary_record(parent_id = nil)`, `has_primary_for(parent_id)`. New records default to non-primary. Adds `primary_flag` to the permitted attributes.

### `PlatformRegistryDefaults`, `PlatformFederationStatus`, `PlatformConnectionOauthCredentials`, `PlatformConnectionSyncTracking`

Platform and connection concerns for federation: registry defaults on create (network visibility `private`, connection bootstrap state, local-hosted and Community Engine defaults), local-versus-external status, per-connection OAuth client credentials, and sync bookkeeping with a circuit breaker. See [Federation System](../developers/systems/federation_system.md).

### `PlatformCspConfiguration`

Per-platform Content-Security-Policy origins. Five settings keys (`csp_frame_ancestors`, `csp_frame_src`, `csp_img_src`, `csp_script_src`, `csp_connect_src`) are stored in the platform's settings, edited as one origin per line through `csp_*_text` accessors, validated before save, and seeded on create with the default map-tile image sources (`ContentSecurityPolicySources::DEFAULT_MAP_TILE_IMG_SOURCES`). See [Embedded Content and CSP](../platform_organizers/embedded_content_and_csp.md).

### `PlatformCssBlockManagement`

Platform helpers for its custom CSS block: `css_block` (the platform's `Content::Css` block), `css_block?`, a `css_block_attributes=` writer, and persistence in an `after_save` hook.

### `PlatformMembershipDisplay`

`memberships_with_associations` loads platform memberships with member translations, profile image and role translations in one query to avoid N+1 queries in membership lists.

## Person reverse associations

`Person` pulls its reverse associations from small concerns so the model stays readable. They add `has_many` associations only.

| Concern | Associations |
|---|---|
| `Communicator` | Sent messages and related person-authored communications |
| `CreatedRecords` | Records the person created (authorships, pages, wizard steps, and others through `creator_id`) |
| `GovernanceParticipant` | Safety notes authored, safety actions acted on and approved, deletion-review roles |
| `InvitationParticipant` | Platform invitations and guest accesses sent and received |

These associations are what `config/person_deletion_inventory.yml` refers to; see [Person Deletion Requests and Purge Audits](../developers/systems/person_deletion_and_purge_audit_system.md).

## Content and media

### `Attachments::Images`

Single place for attached images. The class method `attachable_cover_image` attaches `cover_image` (also reachable as `card_image`) with allowed types `image/jpeg`, `png`, `gif`, `webp` and `svg+xml`, a 100 MB limit, and preprocessed variants (`optimized_jpeg` and `optimized_png` at up to 2400x1200, `optimized_card_jpeg` at up to 1200x300). `optimized_cover_image` and `optimized_card_image` return the original for SVG, the PNG variant for PNG (keeping transparency) and the JPEG variant otherwise. `remove_cover_image = '1'` purges the image on save.

### `Content::BlockAttributes`

Shared styling attributes for content blocks (background, border radius, margin, padding, dimensions). Validates `container_class` against `container` and `container-fluid` (or a custom value), the background image upload, and that dimension values look like `100`, `50%`, `10vh`, `2rem` and similar (`px`, `%`, `vh`, `vw`, `em`, `rem`).

### `Content::ResourceBlockAttributes`

Shared settings for blocks that render a collection of platform records (posts, events, people, communities and similar). Stored in `content_data`: `display_style` (`grid` or `list`), `item_limit` (1 to 50, default 6), `resource_ids` (JSON array or comma list; `parsed_resource_ids`), `community_scope_id`, `show_view_more_link`, plus a translated `view_more_url`.

### `BlockFilterable`

Adds the scope `excluding_blocked_for(person)`: records authored by people the given person has blocked are removed (through `Authorship`); with no person, or no blocks, it returns all records.

### Content security concerns

`ContentSecurity::ScannableAttachment` and `ContentSecurity::ActionTextRichTextControls` are described in [Content Security Ingress System](../developers/systems/content_security_ingress_system.md).

## Geography

### `Geography::Geospatial::One`

Gives a record one geospatial `space` (through `geospatial_space`) with latitude, longitude and elevation delegated to it, and `geocoded?` from the geocoder gem. Automatic self-geocoding is opt-in through `geocodes_self`.

### `Geography::Locatable::Many`

For records that can sit at several levels of the geography hierarchy (settlement, region, state, country, continent) through one `LocatableLocation` per level, resolved from PostGIS polygon containment by `HierarchyResolutionJob`. Include it only in models that get their own geocoded `Space` (`Address`, `Building`). `Event` does not: its placement comes through its `Locatable::One` location.

### `Geography::Placeable`

Marks a model as a valid target of `LocatableLocation#location`. The allow-list is the set of including models (`Placeable.included_in_models`), not a list in the gem. Matching uses a name similarity threshold of 0.2.

## Recurrence

`RecurringSchedulable` is described in [Event Recurrence and Occurrences](../developers/systems/event_recurrence_and_occurrences_system.md).

## MCP

### `Mcp::PunditIntegration`

Shared by MCP tools and resources: includes `Pundit::Authorization` below itself in the ancestor chain so its `pundit_user` wins, and resolves `current_user`, `agent` (the person) and the time zone from the MCP context (`mcp_pundit_context`).

## Related

- [Polymorphic allow-list extension audit](../developers/architecture/polymorphic_allowlist_extension_audit.md)
- [Short Links System](../developers/systems/short_links_system.md) (`Shortlinkable`)
