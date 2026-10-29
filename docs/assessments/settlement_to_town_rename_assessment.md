# Assessment: naming and wording of `Geography::Settlement`

**Status:** Phase 1 (wording: glosses + translation fixes) implemented on branch `claude/charming-rubin-cm2s4m`. Phase 2 (class/table/route rename) is **deferred**; its edit-point map is kept in section 4.
**Trigger:** Community feedback that "Settlement" is not intuitive.
**Scope searched:** `.rb`, `.erb`, `.yml`, `.js`, `.css`, `.rake`, `.json`, `.mmd`, `.md`, `.svg`, `.dbml` across the engine (excluding `node_modules`, `.git`, `log`, `tmp`), plus a read-only pass over the Newfoundland Labrador Online host app (`better-together-solutions/newfoundlandlabradoronline`).

---

## 1. Decision record

| Question | Answer |
|---|---|
| What must the name cover? | Cities, towns, villages, hamlets, First Nations communities and unincorporated places. The original geographic-model spec said "City"; "Settlement" replaced it for accuracy. |
| Rename the model? | **Not now.** No everyday noun fits the scope (Town, City, Village exclude cases; Place and Community are existing models; see 6.4). |
| What fixes "not intuitive"? | A one-line **gloss** wherever the term is introduced, plus **better translations** (the fr/es/uk labels were the weakest part). |
| Do visible wording and URLs change? | Wording yes (per locale). **Paths no**: keeping "Settlement" in English leaves nothing to alias. `/g/settlements`, route helpers, view directory, API type, class and tables are untouched. |
| Can wording differ by locale? | Yes. es/fr/uk now use their natural general-purpose term (2.3). |
| When to revisit? | If feedback shows the objection is the *connotation* of "settlement" (colonial or politically loaded) rather than comprehension. Then pick among the options in section 6 (Locality is the leading candidate) and use sections 4 and 5. |

Sizing for a future rename (unchanged by Phase 1): 181 files / ~1,000 raw matches; ~720 matching lines in `app`, `lib`, `config`, `db`, `spec`; ~260 in `docs`; the rest generated. **No CSS** references and **no application JS** (one Jest fixture). A rename is a data migration, not a text change: the class name is persisted in polymorphic `*_type` columns, navigation items and serialized job arguments (4.6).

---

## 2. Phase 1: what changed and where

### 2.1 Files changed

| Area | File | Change |
|---|---|---|
| Locales | `config/locales/{en,es,fr,uk}.yml` | Reworded values and new keys (2.2, 2.3) |
| i18n-tasks | `config/i18n-tasks.yml` | `ignore_unused` entry for the dynamically built `seed_catalog.geography.categories.*` keys |
| Settlements index view | `app/views/better_together/geography/settlements/index.html.erb` | Gloss `<p id="settlements-description">` under the `h1`; `id="settlements-table"` with `aria-describedby="settlements-description"`; `id="new-settlement-btn"`; "New settlement" via `t('.new')` |
| Settlements new / edit / row | `.../settlements/new.html.erb`, `edit.html.erb`, `_settlement.html.erb` | Hard-coded "New settlement", "Back to settlements", "Editing settlement", the edit page title and "Edit" moved to I18n (`globals.edit` for the row button) |
| State page | `app/views/better_together/geography/states/show.html.erb` | Tab label via `t('.settlements_tab')`; the `id="settlements-tab"` / `aria-controls="settlements"` wiring is unchanged |
| Region page | `app/views/better_together/geography/regions/show.html.erb` | "Settlements in X" heading via `t('.settlements_heading', name:)` |
| Seed catalog | `app/services/better_together/seed_catalog/geography_catalog.rb` | `.label` and `.description` read from I18n (English strings remain as defaults); `.categories` / `.category` return locale-resolved `:label`s via private `localized_label`; `CATEGORIES` constant unchanged |
| Specs | `spec/requests/better_together/geography/{settlements,regions,states}_controller_spec.rb`, `spec/services/better_together/seed_catalog/geography_catalog_spec.rb`, new `spec/dom_contracts/settlements_pages_spec.rb` | Gloss, locale rendering, DOM ids, catalog label per locale |

### 2.2 Where the gloss lives (edit these to reword it)

| Surface | Locale key | Rendered by |
|---|---|---|
| Settlements index page, under the heading | `better_together.geography.settlements.index.description` | `settlements/index.html.erb` (`#settlements-description`) |
| Event / locatable location picker hint | `better_together.locations.picker.hint` | `better_together/locations/_picker.html.erb` via `LocationPickerHelper::LOCALE_SCOPE` |
| Seed catalog card (admin) | `seed_catalog.geography.description` | `SeedCatalog::GeographyCatalog.description` |

English gloss: *"Cities, towns, villages, hamlets, First Nations communities and other named places."* It deliberately lists **cities** first because both seeded records (St. John's, Corner Brook) are cities.

### 2.3 Translation changes

| Concept | en (unchanged) | es | fr | uk |
|---|---|---|---|---|
| Settlement | Settlement(s) | ~~Asentamiento(s)~~ **Localidad(es)** | ~~Établissement(s)~~ **Localité(s)** | ~~Поселення~~ **Населений пункт / Населені пункти** |
| Region settlement | Region settlement(s) | **Localidad(es) de la región** | **Localité(s) de la région** | **Населений пункт / пункти регіону** |

Why: fr *établissement* means an institution, es *asentamiento* usually means an informal or irregular settlement, uk *поселення* skews archaeological or colonial. The host app's own es/fr files already say "Localidades" / "Localités", which corroborates the choice. **All three need native-speaker review** (the glosses especially: es "caseríos", uk "хутори", and "First Nations" as "Primeras Naciones" / "Перших націй").

Key paths reworded in every non-English locale (values only; key names unchanged):

- `activerecord.models.better_together/geography/{settlement,region_settlement}`
- `activerecord.attributes.better_together/geography/{region,settlement}.{settlements,region_settlements}`; `...region_settlement.settlement` is an alias and needs no change
- `better_together.geography.settlements.{show,toolbar}.*` and the new `.index`, `.new`, `.edit` keys
- `better_together.navigation_items.route_names.geography_settlements`
- `resources.{settlement,region_settlement}`
- `better_together.locations.picker.hint`
- uk only: `better_together.geography.regions.index.title` ("Regions" -> "Регіони")

New keys (all four locales): `better_together.geography.settlements.index.{description,new}`, `.new.{heading,back}`, `.edit.{heading,page_title}`, `better_together.geography.regions.show.settlements_heading`, `better_together.geography.states.show.settlements_tab`, `seed_catalog.geography.{label,description}`, `seed_catalog.geography.categories.{continents,countries,provinces,regions,settlements}`.

### 2.4 Deliberately not changed
Class, tables, `settlement_id`, route helpers, `/g/settlements`, controllers, policies, view directory names, DOM class names (`geography-settlement-*`), the API type `geography_settlements`, the MCP `settlement` type, rake `LEVEL=settlement`, seed-catalog URL param `settlements`. Reason: no English wording change that justifies them, and the host app depends on them (2.6). Precedent: `State` is already labelled "Provinces & Territories" in the seed catalog and the host app serves `/g/provinces`.

### 2.5 Still hard-coded or unlocalized (follow-ups, not done)

| Where | What |
|---|---|
| `app/views/better_together/geography/region_settlements/*` (6 files) | Whole scaffold is hard-coded English ("Region settlements", "Show this region settlement", ...) |
| `states/show.html.erb`, `regions/show.html.erb` | Other labels ("Protected:", "Yes"/"No", "Edit this state", "Back to states", "Edit this region", "See all regions") |
| `settlements/show.html.erb` | `aria_label: 'geography-settlement Sections'` is a developer string, not a translated accessible name |
| `app/tools/better_together/mcp/search_geography_tool.rb` | Tool description text |
| `lib/tasks/better_together/geography_*.rake` | `desc` strings (operator-facing, English only) |
| `app/builders/better_together/geography_builder.rb#settlements` | Seed `description:` values are English data ("City in Newfoundland and Labrador") |
| `docs/screenshots/**/event_location_settlement_assigned.*`, `seed_catalog_*` | Narrative text still says "Settlement"; regenerate with `RUN_DOCS_SCREENSHOTS=1` |

### 2.6 Host app: Newfoundland Labrador Online (`better-together-solutions/newfoundlandlabradoronline`)

**Impact of Phase 1:** none breaking. Nothing path-, helper- or class-related changed, so its view overrides keep working. It does not get the gloss until it adopts the change (this session had read-only access to that repo, so nothing was pushed there).

To adopt Phase 1 (host repo):
1. `app/views/better_together/geography/settlements/index.html.erb` (copy of CE `929bb51a9492`): add `<p id="settlements-description" class="text-muted"><%= t('.description') %></p>` under the `h1`, add `id="settlements-table"` + `aria-describedby`, `id="new-settlement-btn"`, replace the literal "New settlement" with `t('.new')`, and update the "Copied from ..." pin comment.
2. `config/locales/{en,es,fr}.yml`: keys `...districts.show.{no_settlements,settlements}` and the regions/states tab label `settlements:` (about lines 139, 143, 240) already read "Localidades" / "Localités" in es/fr; en stays "Settlements". There is no `uk.yml`.

Host-app files that reference the model, for a future Phase 2 (from a read-only scan; re-run the grep in section 7):

- Routes/config: `config/routes.rb` (comment only), `config/initializers/better_together_controllers.rb` (prepends `SettlementPosts`, `SettlementEvents`; includes `SettlementMapHelper`)
- Overrides of CE views: `app/views/better_together/geography/settlements/{index,show}.html.erb`, `.../geography/regions/index.html.erb`, `.../communities/_location_line.html.erb` (uses `geography_settlement_path`)
- Own views using CE helpers: `app/views/newfoundland_labrador_online/{states,districts}/show.html.erb` (`geography_settlement_path`)
- Own code: `app/controllers/concerns/newfoundland_labrador_online/settlement_{events,posts}.rb`, `app/models/newfoundland_labrador_online/settlement_map.rb`, `app/models/concerns/newfoundland_labrador_online/{locatable,locatable_models,location_interface}.rb`, `app/policies/.../{settlement_map,state}_policy.rb`, `app/helpers/.../{settlement_map,listing_map}_helper.rb`, `app/resources/.../locatable_resource.rb`, `app/services/.../live_image.rb`, `app/controllers/newfoundland_labrador_online/{districts,states}_controller.rb`
- Styles: `app/assets/stylesheets/theme.scss` (a comment only)
- Data: `db/schema.rb`, plus copied CE migrations under `db/migrate/*.better_together.rb` (including leftover `joatu_settlements` migrations, which are a different, removed feature)
- Docs/specs: `docs/{settlement-map,locatable-onboarding,regions,live-current-image,district-cover-images,ce-backport-assessment,event-series-and-sessions-design}.md`, diagram `docs/diagrams/source/nlo_district_page_layers.mmd`, ~16 spec files (`spec/requests/.../settlement_{events,posts}_spec.rb`, `spec/support/locatable_record_examples.rb`, ...)

### 2.7 Verification status

| Check | Result |
|---|---|
| YAML parses; new keys present in en/es/fr/uk; interpolation variables match; no legacy term ("asentamiento", "établissement", "поселення") remains in the non-English locales | Passed (ad-hoc script) |
| ERB templates compile; Ruby and spec files pass `ruby -c` | Passed |
| `prspec` (new and existing specs), `rubocop`, `bin/i18n`, `brakeman` | **Not run.** The cloud session has no Docker daemon and Ruby 3.3.6 (repo needs 3.4.12). Run `bin/dc-run bundle exec prspec spec/requests/better_together/geography spec/services/better_together/seed_catalog spec/dom_contracts/settlements_pages_spec.rb spec/requests/better_together/seed_catalog_spec.rb` and `bin/dc-run bin/i18n` before merge. The new specs were written without being executed. |
| Desktop/mobile screenshots (required for modified views) | **Not produced** (needs Chrome + DB). Capture with `bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec <spec>'`; there is no settlements-index screenshot spec yet. |
| `bin/i18n normalize` formatting | The long `description` scalars were folded by hand to 80 columns; run `bin/dc-run bin/i18n normalize` and commit any whitespace-only churn |

---

## 3. What the model is today

`BetterTogether::Geography::Settlement` is the lowest named level of the geography hierarchy:

```
Continent > Country > State (shown as "Province/Territory") > Region >< Settlement
```

- `belongs_to :country`, `belongs_to :state` (both optional); many-to-many with `Region` through `RegionSettlement`.
- Includes `Geospatial::One`, `Placeable`, `Privacy`, `PrimaryCommunity`, `Identifier`, `Attachments::Images`; `geocodes_self`; `slugged :name`.
- Used as: an event/locatable **location target** (picker), a **hierarchy-resolution level** (PostGIS polygon containment), a **boundary-import** target (Nominatim), a **seed catalog** category, a **JSON:API** resource, and an **MCP search** type.
- Seed data: `St. John's` and `Corner Brook`, both described as "City in Newfoundland and Labrador".
- Existing docs describe it as "Cities, towns, and settlement areas" (`docs/developers/systems/geography_system.md:16`).

---

## 4. Edit-point inventory for a future class/path rename

> Everything below is **not** done. It is the map for Phase 2 (renaming the class, tables, routes). Counts are as of commit `c1a2d6c` (before Phase 1). `Town` is used as the example target name; substitute whatever name is chosen. File paths and symbols are authoritative; line numbers are deliberately omitted because they drift (use section 7 to re-find them).

### 4.1 Identifier forms to map

| Old | New (example: `Town`) |
|---|---|
| `Settlement` / `Settlements` | `Town` / `Towns` |
| `settlement` / `settlements` | `town` / `towns` |
| `RegionSettlement(s)` / `region_settlement(s)` | `RegionTown(s)` / `region_town(s)` |
| `GeographySettlement(s)` / `geography_settlement(s)` | `GeographyTown(s)` / `geography_town(s)` |
| `settlement_id`, `settlement_identifier` | `town_id`, `town_identifier` |
| `seed_settlements`, `seed_region_settlements` | `seed_towns`, `seed_region_towns` |
| `available_settlements_for` | `available_towns_for` (see 4.5) |

**Do not blanket-replace.** Three files use "settlement" in the financial/legal sense and must be left alone:
`app/models/better_together/joatu/agreement.rb` (`complete_pending_settlement!`, `cancel_pending_settlement!`), `.github/instructions/notifications-noticed.instructions.md:216` (`@settlement.agreement`), and `app/views/better_together/static_pages/terms_of_service.html.erb:121`.

### 4.2 Application code (`app/`: 50 files, 251 lines; 47 are geography)

| Layer | Files | Notes |
|---|---|---|
| Models (13, 12 geography) | `geography/settlement.rb`, `geography/region_settlement.rb` (rename files + classes); references in `region.rb`, `state.rb`, `locatable_location.rb`, `address.rb`, `event_collection_map.rb`, `navigation_item.rb`, concerns `geospatial/one.rb`, `locatable/located_in.rb`, `locatable/many.rb`, `placeable.rb` | `has_many :settlements` on `Region` and `State`; `LocatableLocation#settlement`, `#settlement?`, `.available_settlements_for`; `Locatable::Many::LEVELS` key `:settlement` |
| Controllers (5) | `geography/settlements_controller.rb`, `geography/region_settlements_controller.rb`, `api/v1/geography_settlements_controller.rb`; refs in `geography/regions_controller.rb` (`includes(:settlements)`), `host_dashboard_controller.rb` | Ivars `@geography_settlement(s)`, flash key `resources.settlement`, redirects |
| Policies (2) | `settlement_policy.rb`, `region_settlement_policy.rb` | Pundit resolves by class name; rename together with models |
| Helpers (3) | `settlements_helper.rb`, `region_settlements_helper.rb`, `location_picker_helper.rb` | Picker helper builds its type map from class name |
| API resource (1) | `api/v1/geography_settlement_resource.rb` | `model_name`, JSON:API `type` changes (external contract, see 4.5) |
| Jobs (2) | `boundary_import_job.rb`, `hierarchy_resolution_job.rb` | `levels:` takes lowercase class names |
| Services / builders / tools (5) | `boundary_fetcher.rb`, `seed_coordinates_generator.rb`, `seed_catalog/geography_catalog.rb`, `geography_builder.rb`, `mcp/search_geography_tool.rb` | `CATEGORIES`, `seed_settlements`, `'settlement' =>` type filter, hard-coded label `'Settlements'` |
| Views (18, 17 geography) | `settlements/{_form,_settlement,edit,index,new,show}`, `region_settlements/{_form,_region_settlement,edit,index,new,show}` (rename dirs and partials); refs in `regions/{_region,index,show}`, `states/show`, `host_dashboard/_overview_tab` | `states/show` and `regions/show` have **hard-coded English** "Settlements" strings |

### 4.3 Routes (`config/`)

- `config/routes.rb:134,137`: `resources :settlements` in `namespace :geography, path: :g` (public index/show + manager-only CRUD) -> `/g/settlements` becomes `/g/towns`.
- `config/routes.rb:542`: `resources :region_settlements` (host dashboard, WIP).
- `config/routes/api_v1.rb:73`: `jsonapi_resources :geography_settlements`.
- `NavigationItem.route_names[:geography_settlements]` (`navigation_item.rb:30`) plus its I18n label.

### 4.4 Locales (`config/locales/{en,es,fr,uk}.yml`)

Keys to rename/relabel in **each** locale (Phase 1 already reworded the *values*; key names are unchanged. Keys added in Phase 1 are marked **new**):

- `activerecord.attributes.better_together/geography/{region,region_settlement,settlement,state}.*` (`settlements`, `region_settlements`, `settlement`)
- `activerecord.models.better_together/geography/{settlement,region_settlement}`
- `better_together.geography.settlements.{index,show,toolbar}.*` plus **new** `.index.description`, `.index.new`, `.new.{heading,back}`, `.edit.{heading,page_title}` (7 original keys incl. `edit-settlement`, `view-all-settlements`, `back_to_geography_settlements`, `save_geography_settlement`, `view_geography_settlement`)
- `better_together.navigation_items.route_names.geography_settlements`
- `helpers.hint.*.geography.settlement.cover_image`
- `resources.settlement`, `resources.region_settlement`
- **new** `better_together.geography.regions.show.settlements_heading`, `better_together.geography.states.show.settlements_tab`
- **new** `seed_catalog.geography.{label,description,categories.settlements}` (and the other four category labels; `SeedCatalog::GeographyCatalog#localized_label` builds the key from the category key)
- `better_together.locations.picker.hint` (wording mentions "settlement")

Defects found during the audit (all **fixed in Phase 1**): `uk` `navigation_items.route_names.geography_settlements` was untranslated English; `uk` `geography.regions.index.title` was the English "Regions"; `fr` "Établissement" means an institution, not a place; `states/show` and `regions/show` bypassed I18n for the settlement strings.

### 4.5 Implicit, name-derived contracts (easy to miss)

These do not contain the word in a way a casual review notices, but break if the class is renamed without them:

1. `LocationsController` (line 44) dispatches to `LocatableLocation.available_#{klass.name.demodulize.underscore.pluralize}_for`. A `Town` class **requires** `available_towns_for`, or the picker lookup fails.
2. `LocatableLocation#location_type_matches?` and `LocationPickerHelper#location_picker_type_map` compare against `klass.name.demodulize.underscore`; the picker's type key changes `settlement` -> `town`. The Jest fixture (`spec/javascript/controllers/location_selector_controller.test.js:19,201,205`) hard-codes both the key and the full class string.
3. `Locatable::Many::LEVELS` key becomes the reader name (`record.settlement` -> `record.town`) and is passed through `level.to_s.camelize`.
4. `Placeable.name_similarity_scope` joins `mobility_string_translations` on `base_class.name`; if translation rows are not migrated, search for towns silently returns nothing.
5. `BoundaryImportJob` `levels:` / rake `LEVEL=settlement` are lowercase class names.
6. `host_dashboard_controller.rb:120` builds ivars from the class name (`@geography_settlements`, `@geography_settlement_count`), consumed in `_overview_tab.html.erb:204`.

### 4.6 Database and data (`db/`, `spec/dummy/db/schema.rb`)

**Schema objects**
- Tables: `better_together_geography_settlements` -> `..._towns`; `better_together_geography_region_settlements` -> `..._region_towns`.
- Column: `region_settlements.settlement_id` -> `town_id`.
- Custom-named indexes that `rename_table` will **not** rename: `bt_region_settlement_by_region`, `bt_region_settlement_by_settlement`, `by_geography_settlement_community`, `by_better_together_geography_settlements_privacy`. Also verify FK names.
- Do **not** edit historical migrations (8 files reference the old names: 2 creators, 2 slug migrations, 4 comment-only). Add one new guarded migration (`table_exists?` / `column_exists?` / `index_name_exists?` per project rules; `create_bt_table` conventions do not apply to renames).
- Regenerate: `spec/dummy/db/schema.rb`, `db/community-engine-db.dbml`, and run `bin/export_schema_diagrams` (CI `Schema Diagrams` job fails otherwise). `bin/parallel-setup` afterwards.

**Persisted class-name strings** (`BetterTogether::Geography::Settlement` -> `...::Town`), confirmed or likely populated:

| Table.column | Why |
|---|---|
| `better_together_geography_geospatial_spaces.geospatial_type` | `Geospatial::One` is `as: :geospatial` |
| `better_together_geography_locatable_locations.location_type` | event locations and hierarchy-resolution placements |
| `mobility_string_translations.translatable_type`, `mobility_text_translations.translatable_type` | translated `name` / `description` |
| `action_text_rich_texts.record_type` | description backend |
| `active_storage_attachments.record_type` | `cover_image` |
| `friendly_id_slugs.sluggable_type` | `slugged :name` |

Audit also (about 45 tables carry `*_type` columns; these could hold Settlement rows): `better_together_navigation_items.linkable_type`, `better_together_metrics_page_views.pageable_type`, `better_together_geography_maps.mappable_type`, `better_together_short_links.linkable_type`, `better_together_federation_content_grants.federatable_type`, `better_together_reports.reportable_type`, `better_together_seeds.seedable_type`, `noticed_events`.

**Other persisted strings**
- `better_together_navigation_items.route_name = 'geography_settlements_url'` is validated against `NavigationItem.route_names.values`; existing rows would become invalid and fail validation on next save.
- **In-flight ActiveJob arguments** (`GeocodingJob`, `HierarchyResolutionJob`, `BoundaryImportJob`) serialize GlobalIDs containing the class name; jobs enqueued before deploy will raise `DeserializationError`. Drain queues first, or ship a temporary `Settlement = Town` constant alias for one release.
- `lib/better_together/geography/seed_coordinates.yml` top-level key `settlements:` and `SeedCoordinatesGenerator::CATEGORIES`.
- Seed catalog URL param: `POST .../catalog/geography/plant/settlements` (`category_key`).

### 4.7 Rake tasks and ops interface (`lib/tasks/better_together/*.rake`: 4 files)

Descriptions in `geography_boundaries`, `geography_reference_data`, `geography_seed_coordinates`, `geography_backfill_placements`; `LEVEL=settlement[,region]` env contract. Accept both values for a deprecation window.

### 4.8 Specs (`spec/`: 44 files, ~340 lines)

10 files/factories are named for the model and need `git mv`:
`factories/.../{settlements,region_settlements}.rb`, `helpers/.../{settlements,region_settlements}_helper_spec.rb`, `models/.../{settlement,region_settlement}_spec.rb`, `policies/.../{settlement,region_settlement}_policy_spec.rb`, `requests/.../{settlements,region_settlements}_controller_spec.rb`.
The other 34 reference the model in setup or assertions (geography API, events, locations_available, seed catalog, boundary/hierarchy jobs, services, tasks, docs-screenshot and DOM-contract specs, `factories_slug_uniqueness_spec`, `active_storage_security_spec`, Jest). Add new specs for redirects and the data migration.

### 4.9 Docs and generated assets

- Hand-edited: 23 `.md`, 10 `.mmd` diagram sources, `ce_documentation_workflows.yml`, `ce_subsystem_inventory.*`, `ce_documentation_coverage_manifest.json`, `geography_system.md`, `CHANGELOG.md` (add entry; do not rewrite history).
- Regenerate: 12 SVG exports (`bin/render_diagrams`), `build/docs/{combined,developers}.md`, `db/community-engine-db*.dbml/.svg`.
- Screenshots: `event_location_settlement_assigned.{png,json,narrative.yml}` (desktop + mobile) and 4 other `*.json`/`*.narrative.yml` sets. Per `AGENTS.md`, every modified view needs new desktop/mobile screenshots, stable DOM ids, and a `spec/dom_contracts` spec. Old PR screenshot folders (`pr - 1659`, `pr - number`) are historical; leave them.
- `config/ci/spec_runtimes.json` lists spec paths; update after renaming spec files.

### 4.10 External consumers (see 2.6 for the host-app file list)

Host apps and extension gems may call `GeographyBuilder.seed_settlements`, `Geography::Settlement`, or `/api/v1/geography_settlements`; MCP clients may send `type: settlement`. Plan aliases for at least one minor release.

---

## 5. Rollout design for a future rename

### 5.1 Phase 1: wording only (DONE, see section 2)
Implemented on this branch: glosses, translation fixes, I18n for the settlement-specific hard-coded strings. No class, table, route, helper, view-directory or API change.

### 5.2 Phase 2: code rename (deferred; may never be needed)
Host app caveat: the Newfoundland Labrador Online host app overrides CE views by path (`app/views/better_together/geography/settlements/{index,show}.html.erb`) and calls `geography_settlement_path` / `geography_settlements_path`. Renaming the view directory would silently drop those overrides, and renaming the route helpers would raise `NoMethodError` in three host files. Phase 2 therefore needs route-helper aliases and a coordinated host-app PR (file list in 2.6).
1. New migration: rename tables, column, custom indexes; `UPDATE ... SET *_type` for every column in 4.6; update `navigation_items.route_name`. Guard every step; make it re-runnable.
2. Rename files/classes/policies/views/factories/specs (`git mv`), then update identifiers per 4.1.
3. Add `available_towns_for`; confirm `LEVELS`, picker key, Jest fixture.
4. Keep a deprecated `Settlement = Town` alias (and `RegionSettlement`) for one release for GlobalID/host-app safety.

### 5.3 Redirects
- Web: `GET /:locale/g/settlements(/:id)(.:format)` -> **301** to `/g/towns(/:id)`, preserving locale and query string. Non-GET legacy paths: **308**. Individual slugs (e.g. `corner-brook`) are unchanged, so deep links and search-engine results survive.
- Host-dashboard `region_settlements` routes: same treatment.
- API: keep `geography_settlements` as a deprecated alias route serving the same data (with `Deprecation`/`Sunset` headers) alongside the new `geography_towns` type, because the JSON:API `type` string is a client contract.
- MCP tool / rake `LEVEL`: accept both values and log a deprecation warning.

### 5.4 Verification
`bin/dc-run bundle exec prspec` on each renamed spec, then `bin/dc-ci`; `bin/dc-run bin/i18n`; rubocop; brakeman; `bin/export_schema_diagrams`; `bin/render_diagrams`; screenshot specs with `RUN_DOCS_SCREENSHOTS=1`. After migrating a copy of production data, assert **no row anywhere still contains `Geography::Settlement`**.

### 5.5 Risk ranking
1. Missed polymorphic `*_type` column (silent data orphaning: records exist but associations return nil).
2. In-flight jobs and stale nav-item `route_name`.
3. External API/host-app breakage.
4. Missing `available_towns_for` (picker returns an error).
5. Everything else is mechanical.

---

## 6. Wording analysis (history: why not Town, Locality or Place)

> Superseded by section 1. Kept so the options are not re-litigated.

### 6.1 Accessibility and plain language

**For Town**
- Everyday, one-syllable, early-primary reading level; "settlement" is a Latinate abstract noun many readers associate with historical colonization or, in some regions, politically charged contexts. That is plausibly the source of the community feedback.
- Short, regular plural, works in sentences: "Events in your town", "Back to Towns".
- No code collisions (zero current uses).
- Rename has no WCAG impact by itself, but the pass is an opportunity to fix hard-coded English in `states/show` and `regions/show` and keep `aria-controls`/`id` pairs consistent (`settlements-tab` -> `towns-tab`).

**Against / caveats**
- Screen-reader users hear the label in the picker as `Corner Brook (Town)`; for a city this reads as an error.
- In the event form, `Address` has a free-text `city_name` and users will see both "City" and "Town" in the same flow.

### 6.2 Accuracy for how the system uses the model

| Concern | Detail |
|---|---|
| Seed data | Both seeded records are **cities** and are described that way (`GeographyBuilder#settlements`, `geography_builder.rb:454`). "Town: St. John's" is a visible inaccuracy on day one. |
| Scope | The Nominatim/OSM sources the system imports from distinguish city, town, village, hamlet. The model is size-agnostic and the picker is the only way to place an event at a place that is not an address. A village or rural community would have no accurate home under "Town". |
| Legal meaning | "Town" is a statutory municipal class in several jurisdictions (including Newfoundland and Labrador, where the seed data lives, and New England/New York), distinct from "city". Users may infer legal status. |
| Hierarchy | It is a leaf under Region/State, so its label must be generic enough to cover every populated place. |
| Translation | `es` "pueblo" implies small/rural (city is "ciudad"); `fr` "ville" covers city and town (good) but "ville" alone reads as "city"; `uk` "місто" is city-or-town and legally distinct from "селище"/"село". The current literal translations ("Asentamiento", "Établissement", "Поселення") are the weak ones, so a rename helps all four locales. |

### 6.3 Alternatives considered

| Candidate | Accessibility | Accuracy | Collision / note |
|---|---|---|---|
| **Town** | High | Medium-low (excludes cities, villages) | None |
| **Town or city** (label) | High | High for most use; still omits hamlets | Label only; awkward as a class name |
| **Locality** | Low-medium (formal) | **High**, size- and status-neutral | None in code; matches OSM/Google/Geocoder terminology. In English as abstract as "Settlement" |
| **Place** | High | Medium (provinces, countries and addresses are places too) | **Rejected**: `BetterTogether::Place` already exists (join of spaces and communities) |
| **Community** | High | Medium | **Rejected**: `BetterTogether::Community` is a core model |
| **City** | High | Low | Excludes most small places |
| **Municipality** | Low | Medium (implies legal incorporation) | Excludes unincorporated places |
| **Neighbourhood / Village** | Medium | Low | Wrong level |
| **Settlement** (kept) | Low-medium | **High**: covers every populated place | Needs a gloss; connotation concerns remain open (section 8) |

### 6.4 Outcome

- **Town / Town or city:** rejected. The model covers villages, hamlets, First Nations communities and unincorporated places, not just municipalities; "Settlement" was chosen over "City" (the original spec) for exactly that reason.
- **Place:** rejected. `BetterTogether::Place` already exists (a join between spaces and communities), and provinces, countries and addresses are all places too.
- **Community:** rejected. `BetterTogether::Community` is a core model.
- **Locality:** accurate and neutral, but in English it is as abstract as "Settlement" and adds little once a gloss is present. Kept as the fallback if the feedback turns out to be about *connotation* rather than comprehension.
- **Settlement (kept):** the noun is abstract whichever word is chosen, so intuitiveness is fixed with a gloss and better translations, not a rename.

---

## 7. Relocation commands (re-find every edit point)

Run from the repo root. Results are authoritative; counts and line numbers in this document will drift.

```bash
# Everything, case-insensitive (the baseline was 181 files)
grep -rIil settlement --exclude-dir={node_modules,.git,log,tmp,coverage} .

# Per area (files / lines)
for d in app lib config db/migrate spec docs build; do echo "$d $(grep -rIil settlement $d | wc -l) $(grep -rIi settlement $d | wc -l)"; done

# Not geography: leave alone (financial/legal sense)
grep -n -i settlement app/models/better_together/joatu/agreement.rb \
  app/views/better_together/static_pages/terms_of_service.html.erb \
  .github/instructions/notifications-noticed.instructions.md

# Locale keys (all four languages)
grep -n -i settlement config/locales/{en,es,fr,uk}.yml

# Name-derived contracts (4.5)
grep -n "available_#{" app/controllers/better_together/locations_controller.rb
grep -n "LEVELS" -A6 app/models/concerns/better_together/geography/locatable/many.rb
grep -rn "location_type_matches?\|location_picker_type_map" app

# Persisted class-name strings: after any rename, this must return 0 rows in every table
#   SELECT table_name, column_name FROM information_schema.columns WHERE column_name LIKE '%\_type';
#   -- then: SELECT count(*) FROM <table> WHERE <column> = 'BetterTogether::Geography::Settlement';

# Files named for the model
find app spec db docs lib -iname '*settlement*' -not -path '*/screenshots/pr*'

# Gloss and Phase 1 keys
grep -rn "settlements-description\|settlements_heading\|settlements_tab\|seed_catalog.geography" app spec config

# Host app (clone read-only, then)
grep -rIil settlement --exclude-dir={node_modules,.git,log,tmp} /path/to/newfoundlandlabradoronline
```

---

## 8. Open questions

1. Is the community objection to the *meaning* ("what is a settlement?") or the *connotation* (colonial or politically loaded)? The first is addressed by Phase 1; the second would reopen the rename (section 6).
2. Native-speaker review of the es/fr/uk terms and glosses (2.3).
3. Should the Newfoundland Labrador Online host app adopt the index-page gloss now (2.6)?
4. Capture screenshots and run the suites listed in 2.7 before merging.
5. Is Phase 2 wanted at all? If yes, decide the alias window for `/api/v1/geography_settlements`, `GeographyBuilder.seed_settlements`, the MCP `settlement` type and rake `LEVEL=settlement`, and whether queues can be drained at deploy (5.2).
