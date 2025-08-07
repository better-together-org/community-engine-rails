# Content Management

This guide covers categories, navigation, page and block editing, resources, events, and maps.

## Categories

- **Topics**, **Journey Stages**, **Events**: Define and organize content categories, sequence journey stages, and tag events for user discovery.
- **Media Defaults**: Configure default card and cover images for event listings and topic thumbnails.

## Navigation

### Areas
- **Named Areas**: Create header, footer, admin, or custom sidebars with support for multiple nesting levels.
- **Visibility & Privacy**: Control which user roles and communities can view each navigation area and schedule publication dates.
- **Performance**: Enable fragment or page caching to speed up menu rendering and reduce backend requests.

### Items
- **Link Items**: Add external URLs, link to internal CMS pages, or reference app resources via dropdown selectors.
- **Dropdowns**: Build hierarchical dropdown menus to organize related links under parent items.
- **Item Settings**: Set publication schedules, role-based visibility, and caching preferences on individual navigation items.

## Content Blocks

- **Block Types**:
  - Rich Text: WYSIWYG editor blocks for formatted text content.
  - Image & Hero: Full-width and inline image banners with captions and alt text.
  - HTML & CSS: Custom markup and style overrides for advanced layouts.
  - Template: Predefined layouts with nested block placeholders.
  - **Future**: Multi-column layouts, embedded content (iFrame), video/audio players, maps, forms, and dynamic lists (people, communities, pages, events).
- **Special Blocks**: Platform-wide CSS overrides, funder acknowledgments, and legal disclaimers.
- **Editor Interface**: Assign unique identifiers, apply style presets, and configure block-specific fields (e.g. image upload, rich-text area).

## Pages

- **Page Management**: Browse, create, duplicate, or delete CMS pages with metadata (title, slug, template).
- **Block Editor**: Drag-and-drop content blocks, reorder sections, and configure hero banners inline.
- **Publishing Controls**: Schedule publication dates, toggle draft mode, and restrict page visibility by role or community.
- **Navigation Assignment**: Attach header or sidebar navigation areas per page for context-sensitive menus.

## Resources

- **Resource Library**: Upload, tag, and categorize downloadable files; version control via uploads history.
- **Access Control**: Set download permissions by role and community membership.

## Events

- **Event Setup**: Define event title, rich-text description, schedule (start/end times), and registration URL.
- **Location & Mapping**: Attach physical or virtual locations, geocode addresses, and embed map widgets.
- **Media & Gallery**: Upload event images or cover photos and set default display sizes.
- **Visibility Settings**: Publish events immediately or schedule publishing; restrict view by community or role.

## Maps

- **Map Integration**: Embed interactive maps showing community boundaries, partner locations, or custom geospatial layers.
- **Customization**: Choose map styles, clusters, and pop-up templates for location markers.

---

For more detailed API reference and code examples, see the [Models & Concerns Overview](models_and_concerns.md) and the [Mermaid diagram](models_and_concerns_diagram.mmd).
