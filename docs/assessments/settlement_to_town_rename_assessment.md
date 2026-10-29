# Assessment: Renaming `Geography::Settlement` (candidate: `Town`)

**Status:** Draft for decision. No code has been changed.
**Trigger:** Community feedback that "Settlement" is not intuitive.
**Scope searched:** `.rb`, `.erb`, `.yml`, `.js`, `.css`, `.rake`, `.json`, `.mmd`, `.md`, `.svg`, `.dbml` across the engine (excluding `node_modules`, `.git`, `log`, `tmp`).

---

## 1. Summary

| Question | Answer |
|---|---|
| How big is the rename? | 181 files / ~1,000 raw matches. ~720 matching lines in `app`, `lib`, `config`, `db`, `spec`; ~260 in `docs`; the rest is generated (`build/`, SVG/JSON exports). |
| Is there a CSS or app-JS impact? | **No CSS.** **No application JS** (only one Jest fixture). The one DOM-level touchpoint is `id="settlements-tab"` / `aria-controls` in `states/show.html.erb`. |
| Is it a text rename only? | No. The class name is **persisted as data** in several polymorphic columns, in navigation items, and in serialized job arguments. A migration is required. |
| Does `Town` collide with anything? | **No.** Zero existing uses of `town`/`towns` in code, views, or locales. |
| Is `Town` accessible? | **Yes**, markedly better than "Settlement" for plain-language reading. |
| Is `Town` accurate? | **Partly.** It is wrong for the two seeded records (both are cities) and excludes villages, hamlets, and rural/unincorporated places. See section 5. |

**Recommendation (short):** "Town" is an improvement in readability but needs its scope widened to be accurate. Either (a) use **"Town or city"** as the English UI label, or (b) pick a neutral code name (e.g. `Locality`) and keep the public label in I18n. A label-only change (Phase 1 below) can ship immediately with zero data risk and lets you test the wording before committing to a class rename.

---

## 2. What the model is today

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

## 3. Complete edit-point inventory

### 3.1 Identifier forms to map

| Old | New (if `Town`) |
|---|---|
| `Settlement` / `Settlements` | `Town` / `Towns` |
| `settlement` / `settlements` | `town` / `towns` |
| `RegionSettlement(s)` / `region_settlement(s)` | `RegionTown(s)` / `region_town(s)` |
| `GeographySettlement(s)` / `geography_settlement(s)` | `GeographyTown(s)` / `geography_town(s)` |
| `settlement_id`, `settlement_identifier` | `town_id`, `town_identifier` |
| `seed_settlements`, `seed_region_settlements` | `seed_towns`, `seed_region_towns` |
| `available_settlements_for` | `available_towns_for` (see 3.5) |

**Do not blanket-replace.** Three files use "settlement" in the financial/legal sense and must be left alone:
`app/models/better_together/joatu/agreement.rb` (`complete_pending_settlement!`, `cancel_pending_settlement!`), `.github/instructions/notifications-noticed.instructions.md:216` (`@settlement.agreement`), and `app/views/better_together/static_pages/terms_of_service.html.erb:121`.

### 3.2 Application code (`app/`: 50 files, 251 lines; 47 are geography)

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

### 3.3 Routes (`config/`)

- `config/routes.rb:134,137`: `resources :settlements` in `namespace :geography, path: :g` (public index/show + manager-only CRUD) -> `/g/settlements` becomes `/g/towns`.
- `config/routes.rb:542`: `resources :region_settlements` (host dashboard, WIP).
- `config/routes/api_v1.rb:73`: `jsonapi_resources :geography_settlements`.
- `NavigationItem.route_names[:geography_settlements]` (`navigation_item.rb:30`) plus its I18n label.

### 3.4 Locales (`config/locales/{en,es,fr,uk}.yml`: 21/19/19/19 lines)

Keys to rename/relabel in **each** locale:

- `activerecord.attributes.better_together/geography/{region,region_settlement,settlement,state}.*` (`settlements`, `region_settlements`, `settlement`)
- `activerecord.models.better_together/geography/{settlement,region_settlement}`
- `better_together.geography.settlements.{index,show,toolbar}.*` (7 keys incl. `edit-settlement`, `view-all-settlements`, `back_to_geography_settlements`, `save_geography_settlement`, `view_geography_settlement`)
- `better_together.navigation_items.route_names.geography_settlements`
- `helpers.hint.*.geography.settlement.cover_image`
- `resources.settlement`, `resources.region_settlement`

Existing defects to fix in the same pass:
- `uk.yml:2770` `geography_settlements: Settlements` is **untranslated English**.
- `fr` uses "Établissement", which means "institution/establishment", not a place.
- `states/show.html.erb` and `regions/show.html.erb` bypass I18n entirely.

### 3.5 Implicit, name-derived contracts (easy to miss)

These do not contain the word in a way a casual review notices, but break if the class is renamed without them:

1. `LocationsController` (line 44) dispatches to `LocatableLocation.available_#{klass.name.demodulize.underscore.pluralize}_for`. A `Town` class **requires** `available_towns_for`, or the picker lookup fails.
2. `LocatableLocation#location_type_matches?` and `LocationPickerHelper#location_picker_type_map` compare against `klass.name.demodulize.underscore`; the picker's type key changes `settlement` -> `town`. The Jest fixture (`spec/javascript/controllers/location_selector_controller.test.js:19,201,205`) hard-codes both the key and the full class string.
3. `Locatable::Many::LEVELS` key becomes the reader name (`record.settlement` -> `record.town`) and is passed through `level.to_s.camelize`.
4. `Placeable.name_similarity_scope` joins `mobility_string_translations` on `base_class.name`; if translation rows are not migrated, search for towns silently returns nothing.
5. `BoundaryImportJob` `levels:` / rake `LEVEL=settlement` are lowercase class names.
6. `host_dashboard_controller.rb:120` builds ivars from the class name (`@geography_settlements`, `@geography_settlement_count`), consumed in `_overview_tab.html.erb:204`.

### 3.6 Database and data (`db/`, `spec/dummy/db/schema.rb`)

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

### 3.7 Rake tasks and ops interface (`lib/tasks/better_together/*.rake`: 4 files)

Descriptions in `geography_boundaries`, `geography_reference_data`, `geography_seed_coordinates`, `geography_backfill_placements`; `LEVEL=settlement[,region]` env contract. Accept both values for a deprecation window.

### 3.8 Specs (`spec/`: 44 files, ~340 lines)

10 files/factories are named for the model and need `git mv`:
`factories/.../{settlements,region_settlements}.rb`, `helpers/.../{settlements,region_settlements}_helper_spec.rb`, `models/.../{settlement,region_settlement}_spec.rb`, `policies/.../{settlement,region_settlement}_policy_spec.rb`, `requests/.../{settlements,region_settlements}_controller_spec.rb`.
The other 34 reference the model in setup or assertions (geography API, events, locations_available, seed catalog, boundary/hierarchy jobs, services, tasks, docs-screenshot and DOM-contract specs, `factories_slug_uniqueness_spec`, `active_storage_security_spec`, Jest). Add new specs for redirects and the data migration.

### 3.9 Docs and generated assets

- Hand-edited: 23 `.md`, 10 `.mmd` diagram sources, `ce_documentation_workflows.yml`, `ce_subsystem_inventory.*`, `ce_documentation_coverage_manifest.json`, `geography_system.md`, `CHANGELOG.md` (add entry; do not rewrite history).
- Regenerate: 12 SVG exports (`bin/render_diagrams`), `build/docs/{combined,developers}.md`, `db/community-engine-db*.dbml/.svg`.
- Screenshots: `event_location_settlement_assigned.{png,json,narrative.yml}` (desktop + mobile) and 4 other `*.json`/`*.narrative.yml` sets. Per `AGENTS.md`, every modified view needs new desktop/mobile screenshots, stable DOM ids, and a `spec/dom_contracts` spec. Old PR screenshot folders (`pr - 1659`, `pr - number`) are historical; leave them.
- `config/ci/spec_runtimes.json` lists spec paths; update after renaming spec files.

### 3.10 External consumers (cannot be searched from this repo)

Host apps and extension gems may call `GeographyBuilder.seed_settlements`, `Geography::Settlement`, or `/api/v1/geography_settlements`; MCP clients may send `type: settlement`. Plan aliases for at least one minor release.

---

## 4. Rollout design

### 4.1 Phase 1: label-only (ship now, zero data risk)
Change only the I18n values (`en/es/fr/uk`), the 3 hard-coded English strings, and the catalog label. Leaves class/routes/DB untouched. Tests the wording with the community and fixes the fr/uk defects.

### 4.2 Phase 2: code rename
1. New migration: rename tables, column, custom indexes; `UPDATE ... SET *_type` for every column in 3.6; update `navigation_items.route_name`. Guard every step; make it re-runnable.
2. Rename files/classes/policies/views/factories/specs (`git mv`), then update identifiers per 3.1.
3. Add `available_towns_for`; confirm `LEVELS`, picker key, Jest fixture.
4. Keep a deprecated `Settlement = Town` alias (and `RegionSettlement`) for one release for GlobalID/host-app safety.

### 4.3 Redirects
- Web: `GET /:locale/g/settlements(/:id)(.:format)` -> **301** to `/g/towns(/:id)`, preserving locale and query string. Non-GET legacy paths: **308**. Individual slugs (e.g. `corner-brook`) are unchanged, so deep links and search-engine results survive.
- Host-dashboard `region_settlements` routes: same treatment.
- API: keep `geography_settlements` as a deprecated alias route serving the same data (with `Deprecation`/`Sunset` headers) alongside the new `geography_towns` type, because the JSON:API `type` string is a client contract.
- MCP tool / rake `LEVEL`: accept both values and log a deprecation warning.

### 4.4 Verification
`bin/dc-run bundle exec prspec` on each renamed spec, then `bin/dc-ci`; `bin/dc-run bin/i18n`; rubocop; brakeman; `bin/export_schema_diagrams`; `bin/render_diagrams`; screenshot specs with `RUN_DOCS_SCREENSHOTS=1`. After migrating a copy of production data, assert **no row anywhere still contains `Geography::Settlement`**.

### 4.5 Risk ranking
1. Missed polymorphic `*_type` column (silent data orphaning: records exist but associations return nil).
2. In-flight jobs and stale nav-item `route_name`.
3. External API/host-app breakage.
4. Missing `available_towns_for` (picker returns an error).
5. Everything else is mechanical.

---

## 5. Is "Town" the right word?

### 5.1 Accessibility and plain language

**For Town**
- Everyday, one-syllable, early-primary reading level; "settlement" is a Latinate abstract noun many readers associate with historical colonization or, in some regions, politically charged contexts. That is plausibly the source of the community feedback.
- Short, regular plural, works in sentences: "Events in your town", "Back to Towns".
- No code collisions (zero current uses).
- Rename has no WCAG impact by itself, but the pass is an opportunity to fix hard-coded English in `states/show` and `regions/show` and keep `aria-controls`/`id` pairs consistent (`settlements-tab` -> `towns-tab`).

**Against / caveats**
- Screen-reader users hear the label in the picker as `Corner Brook (Town)`; for a city this reads as an error.
- In the event form, `Address` has a free-text `city_name` and users will see both "City" and "Town" in the same flow.

### 5.2 Accuracy for how the system uses the model

| Concern | Detail |
|---|---|
| Seed data | Both seeded records are **cities** and are described that way (`GeographyBuilder#settlements`, `geography_builder.rb:454`). "Town: St. John's" is a visible inaccuracy on day one. |
| Scope | The Nominatim/OSM sources the system imports from distinguish city, town, village, hamlet. The model is size-agnostic and the picker is the only way to place an event at a place that is not an address. A village or rural community would have no accurate home under "Town". |
| Legal meaning | "Town" is a statutory municipal class in several jurisdictions (including Newfoundland and Labrador, where the seed data lives, and New England/New York), distinct from "city". Users may infer legal status. |
| Hierarchy | It is a leaf under Region/State, so its label must be generic enough to cover every populated place. |
| Translation | `es` "pueblo" implies small/rural (city is "ciudad"); `fr` "ville" covers city and town (good) but "ville" alone reads as "city"; `uk` "місто" is city-or-town and legally distinct from "селище"/"село". The current literal translations ("Asentamiento", "Établissement", "Поселення") are the weak ones, so a rename helps all four locales. |

### 5.3 Alternatives considered

| Candidate | Accessibility | Accuracy | Collision / note |
|---|---|---|---|
| **Town** | High | Medium-low (excludes cities, villages) | None |
| **Town or city** (label) | High | High for most use; still omits hamlets | Label only; awkward as a class name |
| **Locality** | Low-medium (formal) | **High**, size- and status-neutral | None; matches OSM/Google/Geocoder terminology |
| **Place** | High | Medium | Collides with the `Placeable` concept and `Place` generics |
| **Community** | High | Medium | **Rejected**: `BetterTogether::Community` is a core model |
| **City** | High | Low | Excludes most small places |
| **Municipality** | Low | Medium (implies legal incorporation) | Excludes unincorporated places |
| **Neighbourhood / Village** | Medium | Low | Wrong level |

### 5.4 Recommendation

1. If you want a single word everywhere: **Town is acceptable** *provided* you (a) decide that cities and villages are in scope and say so in the description text, and (b) update the seed descriptions so "City in ..." and "Town" do not contradict.
2. Better fit: **decouple code name from UI label.** The repo already does this for `State`, which the seed catalog labels "Provinces & Territories". Use a neutral class name (`Locality`) and I18n labels such as "Town or city" (en), "Ville ou village" (fr), "Ciudad o pueblo" (es), "Місто або село" (uk). Future wording changes then cost only a locale edit.
3. Whichever you pick, do **Phase 1** first to validate the word with the community before paying for the migration.

---

## 6. Open questions for the maintainer

1. Is the model intended to cover villages, hamlets, First Nations/Indigenous communities, and unincorporated places, or only municipalities?
2. Should user-visible wording differ by locale (recommended), or must it be one word everywhere?
3. How long is the deprecation window for `/api/v1/geography_settlements` and `GeographyBuilder.seed_settlements`?
4. Are there known host apps or extension gems that reference `Geography::Settlement`?
5. Can queues be drained for the deploy, or should the constant alias ship?
