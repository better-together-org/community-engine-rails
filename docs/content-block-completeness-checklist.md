# Content Block Type Completeness Checklist

Every `Content::Block` STI subclass in the CE gem must have all items below to be considered
production-complete. This document is the canonical reference — use it when adding new block
types or auditing existing ones.

---

## Checklist

### 1. Model (`app/models/better_together/content/<block_name>.rb`)

- [ ] STI class inheriting from `Content::Block`
- [ ] `store_attributes :content_data` with all non-translatable config attrs
- [ ] `validates` for required attrs
- [ ] Helper methods for complex attrs (e.g. `parsed_accordion_items`, `embed_url`)
- [ ] `self.content_addable? → true` (unless display-only, e.g. Css)
- [ ] `self.extra_permitted_attributes → super + [all content_data keys]`
- [ ] **For user-visible text:** `include BetterTogether::Translatable` + `translates :attr, type: :text`
  - Use `type: :text` (→ `mobility_text_translations`) **never** `type: :string` (→ `mobility_string_translations`)
  - Generates locale accessors: `attr_en`, `attr_fr`, `attr_es`, `attr_uk`

### 2. Display partial (`app/views/better_together/content/blocks/_<block_name>.html.erb`)

- [ ] Strict locals declaration: `<%# locals: (<block_name>:) -%>`
- [ ] Fragment cache with appropriate cache key (include locale + any data-driving attrs)
- [ ] `render layout: 'better_together/content/blocks/block', locals: { block: <block_name> } do`
- [ ] Meaningful empty-state fallback (not a blank div)
- [ ] Accessible markup (ARIA labels where needed)

### 3. Form fields partial (`app/views/better_together/content/blocks/fields/_<block_name>.html.erb`)

- [ ] Strict locals declaration: `<%# locals: (block:, scope: BetterTogether::Content::Block.block_name, temp_id: SecureRandom.uuid) -%>`
- [ ] Fields for every `content_data` attribute
- [ ] **For translatable attrs:** use `_translatable_string_field` / `_translatable_text_field` shared partials with locale tabs
- [ ] Select/enum fields use `BetterTogether::Content::Block.human_attribute_name` for labels
- [ ] Help text for complex fields (JSON arrays, URL format hints)

### 4. Block picker icon (`app/views/better_together/content/blocks/new/_<block_name>.html.erb`)

- [ ] Custom Font Awesome icon (not the placeholder `fa-question-circle`)
- [ ] Icon communicates what the block does at a glance
- [ ] Follows the same fa-stack/fa-3x markup pattern as existing icons

### 5. Page builder picker card (`app/views/better_together/content/page_blocks/block_types/_<block_name>.html.erb`)

- [ ] Custom Font Awesome icon matching the blocks/new/ icon
- [ ] Includes the `link_to new_page_page_block_path(page, ...)` turbo-stream link
- [ ] Accessible `aria-label`

### 6. I18n strings (`config/locales/en|fr|es|uk.yml`)

- [ ] `better_together.content.blocks.<block_name>.*` — block-specific display strings
- [ ] Empty-state message (`<block_name>.empty`)
- [ ] Error/fallback messages for required attrs
- [ ] Enum labels (e.g. `alert_block.levels.info`, `call_to_action_block.layouts.centered`)
- [ ] All 4 locales: `en`, `fr`, `es`, `uk`

### 7. JSON:API resource (`app/resources/better_together/api/v1/<block_name>_resource.rb`)  ❌ MISSING

- [ ] Inherits from `BetterTogether::Api::ApplicationResource`
- [ ] `model_name '::BetterTogether::Content::<TypeName>'`
- [ ] `attributes` for all readable attrs (incl. `type`, `block_name`)
- [ ] `translatable_attribute` for all translatable attrs
- [ ] `creatable_fields` / `updatable_fields` excluding read-only attrs
- [ ] Association to `PageBlock` (for attaching to pages)

### 8. JSON:API controller and routes ❌ MISSING

- [ ] Controller at `app/controllers/better_together/api/v1/blocks_controller.rb`
  - Polymorphic — works for all block types via STI; uses `BlockResource`
  - Actions: `index` (filter by page_id, type), `show`, `create`, `update`, `destroy`
  - `authenticate_user_from_token!` (OAuth Bearer) or `authenticate_user!`
  - Pundit: `authorize_resource` using `Content::BlockPolicy`
- [ ] Route at `resources :blocks` under `namespace :api / namespace :v1`

### 9. MCP tools ❌ MISSING

- [ ] `list_page_blocks_tool.rb` — list all blocks on a page by page ID or slug
- [ ] `get_block_tool.rb` — get a single block with all attrs by ID
- [ ] `create_page_block_tool.rb` — create a block on a page (type + attrs + position)
- [ ] `update_block_tool.rb` — update a block's attrs (sparse)
- [ ] `delete_page_block_tool.rb` — remove a block from a page (destroys PageBlock join; optionally destroys block)

### 10. Pundit policy

- [ ] Covered by shared `Content::BlockPolicy` — no per-type policy needed ✅
- [ ] Block-type-specific permission rules (if any) go in `BlockPolicy#create?` check

### 11. Factory (`spec/factories/better_together/content/block.rb`)

- [ ] `factory :content_<block_name>` with valid defaults for all required attrs
- [ ] Factory builds a complete, valid record that can be `.create!`'d in a spec

### 12. Model spec (`spec/models/better_together/content/<block_name>_spec.rb`)

- [ ] Validates STI inheritance from `Content::Block`
- [ ] Validates `content_addable?`
- [ ] Tests defaults for all `store_attributes`
- [ ] Tests helper methods (parsing, URL extraction)
- [ ] Tests `extra_permitted_attributes` includes all content_data keys
- [ ] Tests validations (required attrs, inclusion validations)

### 13. View spec — display partial (`spec/views/better_together/content/blocks/_<block_name>_spec.rb`) ❌ MISSING for new types

- [ ] Renders without error using factory-built instance
- [ ] Renders empty-state when no content configured
- [ ] Does not expose unescaped user content (XSS check)

### 14. View spec — form fields partial ❌ MISSING for new types

- [ ] Renders all fields without error
- [ ] Pre-populates existing values on edit

### 15. Request spec ❌ MISSING for block types

- [ ] `POST /api/v1/blocks` — create
- [ ] `GET /api/v1/blocks?page_id=<uuid>` — index filtered by page
- [ ] `PATCH /api/v1/blocks/:id` — update
- [ ] `DELETE /api/v1/blocks/:id` — destroy

---

## Status by Block Type

| Block type | Model | Display | Fields | Icon (new/) | Icon (pb/) | I18n | JSON:API | MCP | Factory | Model spec | View spec |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `Markdown` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `RichText` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Image` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Hero` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Html` | ✅⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Css` | ✅⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `MermaidDiagram` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Template` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `AccordionBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `AlertBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `CallToActionBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `QuoteBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `StatisticsBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `VideoBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `CommunitiesBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `EventsBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `PeopleBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `PostsBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `ChecklistBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `NavigationAreaBlock` | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |

**Legend:**
- ✅ Present and correct
- ⚠️ Present but incomplete (generic placeholder icon OR type:string bug)
- ❌ Missing entirely

**Footnotes:**
- `Html` and `Css` ⚠️: use `translates :content, type: :string` — should be `type: :text`
- `Icon (new/)` ⚠️: all 12 new blocks use `fa-question-circle` placeholder; need block-specific icons
- `Icon (pb/)` ⚠️: `page_blocks/block_types/` partials use same placeholder icons

---

## Known CE Gem Bugs

### 1. `Content::Css` and `Content::Html` — `type: :string` should be `type: :text`

Both models declare `translates :content, type: :string`, routing to `mobility_string_translations`
(`character varying` column). Content should use `type: :text` (`mobility_text_translations`, `text` column).

**Safe on PostgreSQL** (varchar without limit = unlimited). **Truncates at 255 on MySQL/MariaDB.**

**Fix:**
- `app/models/better_together/content/css.rb`: `translates :content, type: :text`
- `app/models/better_together/content/html.rb`: `translates :content, type: :text`
- Migration: move existing `mobility_string_translations` rows for `key = 'content'` and
  `translatable_type IN ('BetterTogether::Content::Css', 'BetterTogether::Content::Html')`
  to `mobility_text_translations`

---

## i18n Completeness — New Block Types

### Tier 1 — Simple migration (add `translates :attr, type: :text` to model)

These blocks have flat string attrs in `content_data` that should be Mobility-translated.
CE currently stores them in `content_data` JSONB (non-translatable).

| Block | Attrs to migrate | Notes |
|---|---|---|
| `AlertBlock` | `heading`, `body_text` | `alert_level`, `dismissible` stay in content_data |
| `CallToActionBlock` | `heading`, `subheading`, `body_text`, `primary_button_label`, `primary_button_url`, `secondary_button_label`, `secondary_button_url` | URLs should be translatable for locale-specific destinations |
| `QuoteBlock` | `quote_text`, `attribution_name`, `attribution_title`, `attribution_organization` | All four are displayed to users |
| `VideoBlock` | `caption` | `video_url`, `aspect_ratio` stay in content_data |
| `StatisticsBlock` | `heading` | `columns` is config; `stats_json` is Tier 2 |
| `AccordionBlock` | `heading` | `open_first` is config; `accordion_items_json` is Tier 2 |
| `Hero` (existing) | `cta_url` | Currently in `content_data`; needs per-locale override |

### Tier 2 — Complex migration (JSON-embedded text arrays)

| Block | Attribute | Approach |
|---|---|---|
| `AccordionBlock` | `accordion_items_json` | Add locale keys inside each item: `{question: {en:…,fr:…}, answer: {…}}` |
| `StatisticsBlock` | `stats_json` | Add locale keys: `{label: {en:…,fr:…}, value: "42", icon: "…"}` |

### Tier 3 — No migration needed

`CommunitiesBlock`, `EventsBlock`, `PeopleBlock`, `PostsBlock`, `NavigationAreaBlock`,
`ChecklistBlock`, `Template` — resource references or config-only; no user-visible text stored.

---

## Implementation Priority

1. **Fix icons** (new/ and page_blocks/block_types/) — cosmetic but needed for usability ✅ low risk
2. **Fix Css/Html type:string bug** — one PR, two model changes + one Mobility migration
3. **JSON:API BlockResource + controller + routes** — enables headless CMS via ce_pages.py
4. **MCP tools for block CRUD** — enables agent-driven content management
5. **Tier 1 i18n migrations** — separate PR per block or one bundled PR
6. **View specs** — test coverage for new block rendering
7. **Tier 2 i18n** — JSON-embedded translation structure
