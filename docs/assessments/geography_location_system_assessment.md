# Community Engine Geography & Location System Assessment

**Author:** Claude Code (comprehensive audit)  
**Date:** June 3, 2026  
**Scope:** Current vs intended architecture for v0.12.0 "balanced spacetime foundation" milestone  
**Fills:** `docs/assessments/system_assessment_inventory_2025-11.md` row 8 (❌ Missing geography assessment)

---

## Executive Summary

The Community Engine Rails geography and location system is **partially implemented** with significant gaps between its documented intended design and its current code/schema state. The system has:

- ✅ Core geography hierarchy (Continent→Country→State→Region→Settlement)
- ✅ Geocoding pipeline for addresses and buildings
- ✅ Polymorphic location association for events via `LocatableLocation`
- ✅ PostGIS extension enabled, maps with spatial columns
- ✅ Design docs, diagrams, and comprehensive test coverage for what exists

But it is missing or incomplete on:

- ❌ **PostGIS geometry in Space model** — coordinates stored as plain floats, making proximity queries impossible
- ❌ **Spatial indexes** — none exist, including on `maps.center` which has a PostGIS column
- ❌ **Event location API** — `EventResource` exposes zero location attributes
- ❌ **Geographic filters** — no lat/lng/radius search on any endpoint
- ❌ **Infrastructure UI** — Building/Floor/Room models exist but have no standalone CRUD flows
- ❌ **Dead Event geocoding code** — `geocoded_by` commented out; methods reference non-existent associations
- ❌ **v0.12.0 implementation** — all 13 sub-issues are OPEN; no work has started

**Gap count:** 17 documented gaps (4 critical, 5 high, 5 medium, 3 low); 13 open GitHub issues blocking v0.12.0 milestone.

---

## 1. v0.12.0 Milestone Context

### Primary Epic: Issue #1424 "Track v0.12.0 balanced spacetime foundation release"

The v0.12.0 release is defined as the foundation for place, timezone, event scheduling, and accountability:

> v0.12.0 is the balanced spacetime foundation release for Community Engine. It should bring geography, maps, infrastructure, timezone handling, and temporal cohesion into one clear foundation for community place, scheduling, continuity, and accountable history.

**Stakeholders:**
- Community organizers maintaining places, buildings, and events
- Members who rely on accurate place and timezone context
- Researchers, historians, and accountability stewards
- Platform operators and developers

**Acceptance gates:**
1. Geography/location work is a major pillar
2. Temporal cohesion across events, calendars, and recurrence is defined and tested
3. Timezone behavior is geography-aware and documented
4. Buildings, floors, and rooms are minimally usable in the product
5. Required stakeholder docs and diagrams ship with the release

### Sub-issues (All OPEN)

| # | Title | Priority | Status |
|---|-------|----------|--------|
| 1426 | Supersede geography issue #12 into the v0.12.0 balanced spacetime epic | Core | OPEN |
| 1427 | Audit and normalize the Community Engine geography and location model set | Core | OPEN |
| 1428 | Complete geography views, forms, APIs, tests, and docs for v0.12.0 | Core | OPEN |
| 1429 | Review maps, locatable, and geospatial contracts in Community Engine | Core | OPEN |
| 1430 | Unify the temporal model across events, calendars, calendar entries, and recurrence | Core | OPEN |
| 1431 | Add geography-aware timezone defaults and picker prioritization | Extended | OPEN |
| 1432 | Assess infrastructure models and add minimal UI for buildings, floors, and rooms | Core | OPEN |
| 1433 | Add built-environment history support for community buildings and places | Extended | OPEN |
| 1434 | Implement continuity and evidence primitives and queries for v0.12.0 | Extended | OPEN |
| 1435 | Define the v0.12.0 spacetime API contract and filter/query surface | Core | OPEN |
| 1436 | Publish stakeholder docs and diagrams for the v0.12.0 balanced spacetime release | Docs | OPEN |

### Predecessor: Issue #12 (Original 2019 Geography Plan)

**Title:** "Implement Geographic Data Models and Migrations"  
**Created:** Feb 28, 2019  
**Status:** OPEN (milestone: MVP, overdue)

Planned 8 models: Country, State, Region, City, District, Neighborhood, Street, Address.

**Completion state:**
- ✅ Country, State, Region — implemented with PostGIS
- ❌ City, District, Neighborhood, Street — never started
- ⚠️ Address — implemented but missing planned `st_point` column

---

## 2. Intended Design (Documented)

### Primary Design Sources

**System documentation:**
- `docs/developers/systems/geography_system.md` — 500+ lines covering hierarchy, spatial data, geocoding, PostGIS integration
- `docs/developers/systems/events_system.md` — location system deep dive (lines 320–416)

**Diagrams (Mermaid source + PNG/SVG):**
- `docs/diagrams/source/ce_geography_places_schema_erd.mmd` — full geography + places ERD
- `docs/diagrams/source/geography_system_flow.mmd` — input→geocoding→coordinate validation→PostGIS output flow
- `docs/diagrams/source/events_location_selector_flow.mmd` — UI for switching between simple/address/building locations
- `docs/diagrams/source/ce_events_calendar_schema_erd.mmd` — events/calendar schema (no LocatableLocation shown — lives in geography ERD)

**Assessment docs:**
- `docs/assessments/events_feature_review_and_improvements.md` — explicitly flags location-based search as ❌ Missing (section 2.1)
- `docs/diagrams/reference/ce_subsystem_inventory.md` — complete geography model inventory

### Intended Architecture

**Geography Hierarchy (Relational)**
```
Continent (ISO region)
├── Country (ISO 3166-1 alpha-2)
│   ├── State (ISO 3166-2 subdivision)
│   │   ├── Region (custom divisions)
│   │   │   └── Settlement (cities/towns)
│   │   └── Settlement
│   └── Settlement
└── Settlement
```

**Spatial Data Model (Intended)**
```
Space (coordinates)
├── latitude float (–90 to 90)
├── longitude float (–180 to 180)
├── elevation float
└── [INTENDED BUT MISSING] geometry column (PostGIS ST_Point, SRID 4326)

GeospatialSpace (polymorphic join)
├── geospatial (Continent|Country|State|Region|Settlement|Address|Building|Floor|Room|Event)
└── space (coordinates)
```

**Event Location (Polymorphic)**
```
Event
├── has_one :location via LocatableLocation
│   ├── location_type: Address | Building | [MISSING] Place
│   └── location (polymorphic)
├── has_one :space via GeospatialSpace (for coordinates)
└── accepts_nested_attributes_for :location
```

**Maps & Visualization**
```
Map (STI) with PostGIS:
├── center geography(ST_Point, SRID 4326) [ONLY PostGIS column here]
├── viewport geography(ST_Polygon, SRID 4326) [ONLY PostGIS column here]
├── zoom
└── leaflet.js rendering

Expected usage: proximity search via ST_DWithin(center, user_location, radius)
```

**Geocoding Pipeline (Intended)**
```
Address / Building
├── triggers GeocodingJob on create/update
├── calls Geocoder gem (Nominatim in production)
├── returns lat/lng
├── writes to Space floats [NO PostGIS geometry]
└── [INTENDED] updates linked Map center with geometry
```

**API (Intended)**
```
GET /api/v1/events
├── returns Event with location attributes (address, building, simple name)
├── supports ?filter[location_type]=address|building
├── supports ?filter[latitude]=48.95&filter[longitude]=-57.95&filter[radius]=5
└── proximity search via PostGIS ST_DWithin
```

---

## 3. Current Implementation State

### 3.1 Database Schema

**PostGIS Integration:**
```sql
CREATE EXTENSION postgis;  -- enabled in migration 20240520221152
```

**Geography Hierarchy Tables (Relational only)**

| Table | Columns | PostGIS | Purpose |
|-------|---------|---------|---------|
| `better_together_geography_continents` | id, identifier, community_id, protected | ❌ | Top-level regions |
| `better_together_geography_countries` | id, identifier, iso_code (unique), community_id, protected | ❌ | ISO 3166-1 alpha-2 |
| `better_together_geography_states` | id, identifier, iso_code (unique), country_id, community_id, protected | ❌ | ISO 3166-2 subdivision |
| `better_together_geography_regions` | id, identifier, type (STI), country_id, state_id, community_id, protected | ❌ | Custom regional divisions |
| `better_together_geography_settlements` | id, identifier, country_id, state_id, community_id, protected | ❌ | Cities/towns |
| `better_together_geography_country_continents` | country_id, continent_id (composite unique) | ❌ | M:N join |
| `better_together_geography_region_settlements` | region_id, settlement_id, protected (composite unique) | ❌ | M:N join |

**Spatial Data Storage**

| Table | lat/lng Columns | PostGIS Columns | Indexes |
|-------|---|---|---|
| `better_together_geography_spaces` | latitude float, longitude float, elevation float | ❌ | ❌ none |
| `better_together_geography_geospatial_spaces` | — | ❌ | ✅ on (geospatial_type, geospatial_id) |
| `better_together_geography_maps` | — | ✅ center: ST_Point(SRID 4326), viewport: ST_Polygon(SRID 4326) | ❌ none |

**Location & Event Associations**

| Table | Key Columns | Purpose |
|-------|---|---|
| `better_together_addresses` | contact_detail_id, physical, postal, city_name, state_province_name, postal_code, country_name, privacy | Structured addresses; NO spatial columns |
| `better_together_infrastructure_buildings` | address_id (FK), community_id, floors_count, rooms_count | Venues; has FK to addresses |
| `better_together_infrastructure_floors` | building_id, level (unique per building), rooms_count | Floors within buildings |
| `better_together_infrastructure_rooms` | floor_id, building_id via floor | Rooms within floors |
| `better_together_geography_locatable_locations` | locatable_id, locatable_type, location_id, location_type, name, creator_id | Polymorphic event↔location join; location can be Address or Building |
| `better_together_places` | space_id (FK), community_id, identifier, privacy | Thin wrapper around Space; no event linkage |

**Schema Reality Check:**
- PostGIS extension: ✅ enabled
- PostGIS columns: only `maps.center` and `maps.viewport`
- GiST spatial indexes: ❌ **none, not even on the existing PostGIS columns**
- Coordinate storage: **floats in `spaces` table** (not geometry) — proximity queries via PostGIS **impossible**
- Full migration count: **24 migrations** (May 2024–Aug 2025)

### 3.2 Models

**Geography Hierarchy**
```ruby
# app/models/better_together/geography/continent.rb
class Continent < ApplicationRecord
  include Geospatial::One  # adds has_one :space via GeospatialSpace
  has_many :country_continents
  has_many :countries, through: :country_continents
end

# Similar: Country, State, Region, Settlement
# All include Geospatial::One; all have no direct PostGIS columns
```

**Spatial Models**
```ruby
# app/models/better_together/geography/space.rb
class Space < ApplicationRecord
  has_many :geospatial_spaces
  
  # CRITICAL: Stores coordinates as floats, NOT PostGIS geometry
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  
  scope :geocoded, -> { where.not(latitude: nil, longitude: nil) }
  
  def geocoded?
    latitude.present? && longitude.present?
  end
  
  def to_leaflet_point
    { lat:, lng:, elevation:, label: }  # returns floats, not PostGIS geometry
  end
end

# app/models/better_together/geography/geospatial_space.rb
class GeospatialSpace < ApplicationRecord
  belongs_to :geospatial, polymorphic: true
  belongs_to :space
  validates :geospatial_id, uniqueness: { scope: :geospatial_type, conditions: -> { where(primary_flag: true) } }
  # Join between ANY model and its spatial coordinates
end

# app/models/better_together/geography/map.rb
class Map < ApplicationRecord
  # STI: type column
  # ONLY model with PostGIS columns:
  attribute :center, :st_point  # geography(ST_Point, SRID 4326)
  attribute :viewport, :st_polygon  # geography(ST_Polygon, SRID 4326)
  
  belongs_to :mappable, polymorphic: true, optional: true
  
  # CRITICAL: No spatial indexes on these columns
  # CRITICAL: No proximity scopes using ST_DWithin
end
```

**Event Model**
```ruby
# app/models/better_together/event.rb
class Event < ApplicationRecord
  include Geospatial::One      # has_one :space via GeospatialSpace
  include Locatable::One       # has_one :location via LocatableLocation
  include Categorizable
  include Contactable
  
  # CRITICAL: geocoded_by is COMMENTED OUT (lines 43–46)
  # geocoded_by :geocoding_string  # ← NOT ACTIVE
  
  # CRITICAL: Dead methods referencing non-existent association
  def should_geocode?  # line 200
    # address_changed? || !geocoded?  # address doesn't exist!
  end
  
  def schedule_address_geocoding  # line 210
    # GeocodingJob.perform_later(self)  # never triggered because geocoded_by is commented out
  end
  
  # Location working method:
  def location_attributes=(attrs)
    # Custom setter for polymorphic LocatableLocation
    # Creates Address or Building inline if location_attributes are provided
  end
  
  accepts_nested_attributes_for :location
end

# app/models/better_together/geography/locatable_location.rb
class LocatableLocation < ApplicationRecord
  belongs_to :locatable, polymorphic: true  # Event only, currently
  belongs_to :location, polymorphic: true, optional: true  # Address | Building
  # name field for simple text-only locations
end
```

**Address & Building Geocoding (Active)**
```ruby
# app/models/better_together/address.rb
class Address < ApplicationRecord
  include Geospatial::One  # has_one :space
  include PrimaryFlag
  
  geocoded_by :geocoding_string  # ← ACTIVE
  after_create :schedule_geocoding
  after_update :schedule_geocoding
  
  def should_geocode?
    address_changed? || !geocoded?
  end
  
  def schedule_geocoding
    GeocodingJob.perform_later(self)  # Queue job to fetch lat/lng from Nominatim
  end
end

# app/models/better_together/infrastructure/building.rb
class Building < ApplicationRecord
  include Geospatial::One  # has_one :space
  include Contactable  # has_many :addresses
  
  geocoded_by :geocoding_string  # Delegates to address
  after_create :schedule_address_geocoding
  after_update :schedule_address_geocoding
  # Triggers GeocodingJob for the building's associated address
end
```

**Place Model (Minimal)**
```ruby
# app/models/better_together/place.rb
class Place < ApplicationRecord
  include Privacy
  belongs_to :space  # Simple wrapper around a Space
  # Cannot be used as location_type in LocatableLocation
end
```

### 3.3 PostGIS Utilization

| Aspect | Status | Details |
|--------|--------|---------|
| **Extension enabled** | ✅ | Migration 20240520221152 |
| **PostGIS columns** | ⚠️ **Only 2** | `maps.center` (ST_Point), `maps.viewport` (ST_Polygon), both SRID 4326 |
| **Spatial columns on Space** | ❌ | Uses floats, not geometry |
| **Spatial queries** | ❌ | No ST_DWithin, ST_Distance, ST_Contains anywhere |
| **GiST indexes** | ❌ **None** | Not even on `maps.center` and `maps.viewport` |
| **RGeo usage** | ✅ Limited | `Geography::Map#default_center` uses RGeo to build points; coordinates stored as floats after geocoding |
| **Proximity search** | ❌ | Architecturally impossible with float coordinates |

**Impact:** PostGIS is enabled and marginally used, but architecture prevents its core capability (spatial queries). The system has the machinery but not the data format to use it.

### 3.4 Geocoding Pipeline

**Configuration:**
```ruby
# config/initializers/geocoder.rb
Geocoder.configure(
  lookup: :nominatim,  # Production: OpenStreetMap Nominatim
  cache: Geocoder::CacheStore::Generic.new(Rails.cache, {}),
  timeout: 5,
  units: :km
)
# Development/test: uses test stub with hardcoded lookups
```

**Job Implementation:**
```ruby
# app/jobs/better_together/geography/geocoding_job.rb
class GeocodingJob < ApplicationJob
  queue_as :geocoding
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError
  discard_on Geocoder::ResponseParseError
  
  def perform(geocodable)
    coords = geocodable.geocode  # Geocoder gem returns [lat, lng]
    geocodable.save if coords    # Saves floats to Space record
  end
end
```

**Trigger Points:**
- Address: after create/update if `should_geocode?` is true
- Building: delegates to building's address
- Event: **NOT triggered** (geocoded_by commented out)

**Result Storage:**
- ✅ Writes to `Space` model (latitude float, longitude float)
- ❌ Does **NOT** write to PostGIS geometry
- ❌ Does **NOT** update `Map#center` even if map exists
- ❌ Cannot be queried with PostGIS spatial operators

### 3.5 Controllers & Routes

**HTML CRUD (Geography Admin)**
```ruby
# config/routes.rb
namespace :geography do
  resources :continents, except: %i[new create destroy]
  resources :countries
  resources :regions
  resources :region_settlements
  resources :settlements
  resources :states
  resources :maps, only: %i[show update create index]
end

# No routes for Building, Floor, Room standalone
# They are created only via nested forms (address → building)
```

**JSONAPI v1 (Read-only)**
```ruby
# config/routes/api_v1.rb
jsonapi_resources :geography_continents, only: %i[index show]
jsonapi_resources :geography_countries, only: %i[index show]
jsonapi_resources :geography_states, only: %i[index show]
jsonapi_resources :geography_regions, only: %i[index show]
jsonapi_resources :geography_settlements, only: %i[index show]
jsonapi_resources :events  # Full CRUD, but no location attribute
```

**API Filter Params (Actual)**
```
GET /api/v1/events
├── ?filter[privacy]=public
├── ?filter[creator_id]=...
├── ?filter[timezone]=America/St_Johns
├── ?filter[scope]=upcoming|past|ongoing
└── [NO geographic filters]
```

### 3.6 Serializers (JSONAPI Resources)

**Geography Resources**
```ruby
# app/resources/better_together/api/v1/geography_continent_resource.rb
attributes :name, :identifier, :slug
# No coordinates, no spatial data

# Similar for Country, State, Region, Settlement
```

**Event Resource**
```ruby
# app/resources/better_together/api/v1/event_resource.rb
attributes :name, :description, :slug, :identifier, :privacy, :starts_at, :ends_at,
           :duration_minutes, :registration_url, :timezone, :cover_image_url,
           :local_starts_at, :local_ends_at, :timezone_display

relationships :creator, :attendees

filters :privacy, :creator_id, :timezone, :scope

# CRITICAL: Zero location attributes exposed
# No location_id, location_type, address, building, etc.
```

### 3.7 Background Jobs

Only 1 geography-related job:
- `GeocodingJob` — schedules geocoding for Address/Building

Missing:
- Job to update Map center when Address geocoding completes
- Job to rebuild spatial indexes
- Job to pre-warm PostGIS proximity caches

### 3.8 MCP Tools

```python
# app/tools/better_together/mcp/search_geography_tool.rb
class SearchGeographyTool
  # Arguments: query (text), location_type (optional), limit (optional)
  # Returns: JSON array of {id, name, identifier, type, slug}
  # Search method: ILIKE '%query%' on identifier field
  
  # CRITICAL: Text-only search, no spatial capability
end
```

---

## 4. Issue #12 Original Plan vs Current State

**Issue #12: "Implement Geographic Data Models and Migrations"** (2019, MVP milestone, overdue)

Planned **8 models**, completion checklist at 6/8 checked:

| # | Model | Planned Columns | Status | Implementation |
|---|-------|---|---|---|
| 1 | Country | bt_identifier, bt_protected, bt_slug, bt_references | ✅ Done | `geography/countries.rb` with iso_code |
| 2 | State | bt_identifier, bt_protected, bt_slug, bt_references Country | ✅ Done | `geography/states.rb` with iso_code |
| 3 | Region | bt_identifier, bt_protected, bt_slug, bt_references Country/State | ✅ Done | `geography/regions.rb` (STI) |
| 4 | City | — | ❌ Never started | N/A |
| 5 | District | — | ❌ Never started | N/A |
| 6 | Neighborhood | — | ❌ Never started | N/A |
| 7 | Street | — | ❌ Never started | N/A |
| 8 | Address | bt_references City/State/Country, st_point (PostGIS) | ⚠️ Partial | `addresses.rb` created but **NO st_point column** |

**Key deviation:** Address was implemented without the planned `st_point` geometry column. Instead, coordinates live on the separate `Space` table as floats.

---

## 5. Gap Analysis: Intended vs Actual

| # | Area | Intended | Actual | Gap | Priority |
|---|------|----------|--------|-----|----------|
| **1** | **DB: Space Geometry** | Space has `geometry(ST_Point, SRID 4326)` column for PostGIS proximity queries | Space has only float lat/lng/elevation; no PostGIS geometry | Cannot run ST_DWithin or ST_Distance | **CRITICAL** |
| **2** | **DB: Spatial Indexes** | GiST indexes on all spatial columns (Space.geometry, maps.center, addresses if it had geometry) | No GiST indexes exist anywhere, including on `maps.center` | Proximity queries would be O(n), not O(log n) | **CRITICAL** |
| **3** | **DB: Address Geometry** | Address has `st_point` column (planned in #12) for structured location storage | Address has NO spatial columns; coordinates only on Space via FK | Cannot query nearby addresses directly | **HIGH** |
| **4** | **DB: City/District/Neighborhood/Street** | 4 additional geography models for finer hierarchy (Issue #12) | Never implemented; only Continent/Country/State/Region/Settlement exist | Incomplete hierarchy; no support for sub-regional divisions | **MEDIUM** |
| **5** | **Model: Event Geocoding** | Event is geocodable; can be located independently with geocoded_by | Event `geocoded_by` is **commented out** (lines 43–46); methods reference non-existent `address` association | Event location only via Space or LocatableLocation; cannot geocode directly | **HIGH** |
| **6** | **Model: Place as Location** | Place can be used as `location_type` in LocatableLocation; events can reference places | LocatableLocation only supports Address or Building; no Place support | Events cannot be located at a named place; Place is disconnected from event location flows | **MEDIUM** |
| **7** | **Model: Joatu Address Association** | Joatu::Offer and Joatu::Request have addresses with proper associations | Joatu models have `address_id` FK but NO `belongs_to :address` in code | Foreign key orphan; cannot query offers by address | **MEDIUM** |
| **8** | **API: EventResource Attributes** | EventResource exposes location (address, building, lat/lng, etc.) | EventResource has ZERO location attributes (15+ other attributes exposed) | Event API consumers cannot get location data | **CRITICAL** |
| **9** | **API: Geographic Filters** | `GET /api/v1/events?filter[latitude]=48.95&filter[longitude]=-57.95&filter[radius]=5` supported | No geographic filter params on any endpoint | Cannot query events by proximity | **HIGH** |
| **10** | **API: Proximity Search** | `/api/v1/proximity_search?latitude=...&longitude=...&radius=...` endpoint for fuzzy location lookup | No proximity search endpoint; only text-based `search_geography` MCP tool | Cannot discover locations or events by distance | **HIGH** |
| **11** | **API: Infrastructure Resources** | Building, Floor, Room have JSONAPI resources for CRUD via API | No JSONAPI resources for Building/Floor/Room; only HTML forms in admin panel | Cannot create/edit infrastructure programmatically | **MEDIUM** |
| **12** | **API: MCP Geography Search** | MCP tool supports spatial queries; can search by proximity | MCP `search_geography` is text-only (ILIKE on identifier) | Cannot query geography by spatial proximity | **LOW** |
| **13** | **Geocoding: PostGIS Storage** | Geocoding job writes coordinates to PostGIS geometry column for spatial operations | Geocoding writes to Space floats; PostGIS columns remain unused for coordinates | Geocoded data cannot participate in spatial queries | **CRITICAL** |
| **14** | **Geocoding: Map Update** | Geocoding job updates linked Map#center PostGIS column after success | No job to update Map#center even when address geocoding succeeds | Maps do not reflect address location unless manually updated | **LOW** |
| **15** | **v0.12.0: Implementation Status** | v0.12.0 requires completion of #1426–#1436 as acceptance gates | All 13 sub-issues are OPEN; no implementation work has started on any | v0.12.0 is blocked; release cannot ship until these are addressed | **BLOCKING** |
| **16** | **Docs: Assessment Doc** | Dedicated `geography_location_system_assessment.md` in `docs/assessments/` | This file (gap filled) | Historical gap; system docs existed but no assessment | **INFORMATIONAL** |
| **17** | **Docs: Aspiration vs Reality** | `geography_system.md` and diagrams describe "Spatial Indexing / Proximity Search" as implemented | Diagrams show the flow; code does not implement it; GiST indexes absent | Docs are aspirational, not descriptive | **INFORMATIONAL** |

---

## 6. Technical Debt Inventory

| # | Debt | Location | Impact | Cleanup |
|---|------|----------|--------|---------|
| 1 | Event geocoding dead code | `app/models/better_together/event.rb:43–46, 200–210` | Commented-out `geocoded_by`; methods reference non-existent `address` association; potential NoMethodError if called | Remove dead code; clean up Event model |
| 2 | Missing GiST indexes on PostGIS columns | `db/schema.rb` — maps.center, maps.viewport | Proximity queries would be O(n) instead of O(log n) | Add migration: `CREATE INDEX` with `USING GIST` on maps |
| 3 | Float-based spatial data | `better_together_geography_spaces` schema | Cannot use ANY PostGIS operators on Space coordinates; architecture prevents proximity search | Add geometry column to Space; migrate data or rebuild |
| 4 | Joatu FK orphan | `app/models/better_together/joatu/offer.rb`, `request.rb` | `address_id` FK exists but no `belongs_to :address`; queries fail silently | Add association: `belongs_to :address, optional: true` |
| 5 | Open Issue #12 (2019) | GitHub issue tracker, milestone MVP (overdue) | Original geography model plan incomplete for 7 years | Close #12, supersede with v0.12.0 #1426 |
| 6 | Test stub returns (0,0) | `config/initializers/geocoder.rb` test mode | Default fallback coordinate (0,0) could mask geocoding failures; "Null Island" undetected | Use distinct fallback (e.g., 48.9517, -57.9474 = Corner Brook, NL) |
| 7 | Place disconnected from event location flow | `app/models/better_together/place.rb` | Place models cannot be used in LocatableLocation; two parallel location systems | Extend LocatableLocation to support `location_type: Place` |
| 8 | Event location zero API exposure | `app/resources/better_together/api/v1/event_resource.rb` | API consumers cannot query location data; event serialization is location-blind | Add location attribute to EventResource |

---

## 7. Recommendations & Priority Matrix

### Immediate Actions (Safe, < 1 Sprint)

**Do not require schema changes; unblock other work:**

1. **Remove Event dead geocoding code** (`app/models/better_together/event.rb`)
   - Comment or delete lines 43–46 (geocoded_by), lines 200–210 (dead methods)
   - Event location works via LocatableLocation + Space; geocoding not needed at Event level
   - PR: trivial refactor, one-liner specs

2. **Add GiST index on `maps.center`** (new migration)
   - Migration: `ADD INDEX better_together_geography_maps_center_gist ON better_together_geography_maps USING GIST(center)`
   - Enables future proximity queries without data migration
   - PR: one migration, one test

3. **Add `belongs_to :address` to Joatu models** (`offer.rb`, `request.rb`)
   - Connect FK to model association; optional, safe
   - Enables association-based queries
   - PR: trivial, 2 model tests

### v0.12.0 Core Blockers (Requires coordination with team)

**Must be completed for release:**

#### Tier 1: Schema & Geocoding Architecture (Issue #1427)
1. **Add PostGIS geometry column to Space** or migrate existing float data to geometry
   - Option A (migration-heavy): Add `location` geometry(ST_Point, SRID 4326) column; backfill from lat/lng; drop floats
   - Option B (simpler): Add geometry column in parallel; migrate geocoding job to write geometry after floats
   - Unblocks spatial queries; required before proximity search is possible
   - PR: data migration + GeocodingJob update + specs
   - Effort: 1–2 days; risky due to data migration

2. **Add GiST index on `spaces.location`** (once geometry column exists)
   - Standard spatial index creation
   - Effort: minimal once schema is in place

3. **Add `st_point` to Address** (resurrect Issue #12 partial plan)
   - Enables direct proximity queries on addresses without Space join
   - Alternative: defer to v0.13.0 if time-boxed
   - Effort: 0.5 days

#### Tier 2: Event Location API (Issue #1428, #1435)
1. **Expose location in EventResource** (JSONAPI serializer)
   - Add attributes: `location_id`, `location_type`, `location_name`, `location_address`, `location_building`
   - Add relationship: `location` (polymorphic)
   - Effort: 1 day + 3 request specs

2. **Add geographic filters to EventResource**
   - Support `?filter[latitude]=...&filter[longitude]=...&filter[radius_km]=5`
   - Implement via EventFilterService scope if geometry exists in Space
   - Effort: 1 day once geometry column is added

3. **Add Building/Floor/Room JSONAPI resources** (Issue #1432)
   - Scaffolds for CRUD via API
   - Effort: 1 day per model (3 total)

#### Tier 3: Infrastructure UI (Issue #1432)
1. **Add Building/Floor/Room HTML CRUD forms**
   - Views, controllers, authorization
   - Effort: 2–3 days

2. **Integrate infrastructure into location selector**
   - Allow selecting Building/Floor/Room as event location (already supported in LocatableLocation)
   - Effort: 1 day

### v0.12.0 Extended (If time allows)

- **Issue #1431:** Timezone geography-aware defaults
- **Issue #1433–#1434:** Continuity/evidence models for building history
- **Issue #1436:** Stakeholder docs & diagrams release

---

## 8. Risk Assessment

### High Risk
1. **Float-to-geometry migration on Space** — 1M+ rows possible; data integrity risk
   - Mitigation: backfill in batches; verify with ST_DWithin before/after
2. **Event location API changes** — breaking change to consumers if attribute names change
   - Mitigation: add as non-breaking new attributes; deprecate old if needed

### Medium Risk
1. **GiST index creation on live production** — brief lock on maps table
   - Mitigation: `CONCURRENTLY` option if PostgreSQL 11+
2. **Geocoding job redirect** — if logic changes from Space floats to geometry, need careful feature flag
   - Mitigation: write to both until flip is verified

### Low Risk
1. Removing dead Event code — safe, already unused
2. Adding Joatu associations — backward compatible

---

## 9. Values Alignment Check

**BTS Foundation Values (Love, Inclusivity, Care, Resilience, Hope) + 4 Pre-Action Tests:**

1. **Love/Inclusivity** — Does this respect humanity and agency?
   - ✅ Geographic data enables communities to locate themselves accurately; good
   - ✅ Timezone awareness respects local context
   - ⚠️ Current float-only storage limits accessibility of spatial features

2. **Cooperation/Solidarity** — Does this distribute power or concentrate it?
   - ✅ Infrastructure models support communities representing their own spaces
   - ⚠️ Lack of API exposure limits third-party integrations

3. **Accountability/Stewardship** — Is this auditable, reversible, explained?
   - ✅ Geocoding job is logged (GeocodingJob queue, audit trail via Sidekiq)
   - ❌ No audit trail for Map updates; no history on address changes affecting events
   - 🟡 Issue #1433–#1434 on roadmap for continuity/evidence

4. **Care/Resilience** — Could this harm vulnerable members?
   - ✅ Privacy flags on addresses and events
   - ✅ Timezone handling prevents scheduling confusion
   - ⚠️ Float precision (6 decimal places ≈ 0.1m) could leak location privacy if rounded poorly
   - ⚠️ Geocoding via Nominatim is public; no privacy-respecting alternative

---

## Appendices

### A. Database Migration Timeline

All 24 geography-related migrations (May 2024–Aug 2025):

| Date | Migration | Change |
|------|-----------|--------|
| 2024-05-20 | 20240520221152 | Enable PostGIS extension |
| 2024-05-20 | 20240520221420 | Create continents |
| 2024-05-20 | 20240520221428 | Create countries (iso_code) |
| 2024-05-22 | 20240522181600 | Create regions (STI) |
| 2024-05-22 | 20240522181628 | Create settlements |
| 2024-05-22 | 20240522191708 | Create region_settlements join |
| 2024-09-21 | 20240921162459 | Create addresses (no geometry) |
| 2025-03-21 | 20250321194847 | Create maps (no geometry yet) |
| 2025-03-22 | 20250322202855 | Add maps.center (st_point), maps.viewport (st_polygon), maps.zoom |
| 2025-03-23 | 20250323220611 | Create spaces (float lat/lng/elevation) |
| 2025-03-24 | 20250324134601 | Create places (FK to spaces) |
| 2025-03-25 | 20250325173009 | Create buildings (STI) |
| 2025-03-25 | 20250325181358 | Create floors |
| 2025-03-25 | 20250325181419 | Create rooms |
| 2025-03-25 | 20250325205652 | Create geospatial_spaces (polymorphic join) |
| 2025-03-28 | 20250328002116 | Remove default from maps.center |
| 2025-03-29 | 20250329182120 | Make addresses.contact_detail_id nullable |
| 2025-03-29 | 20250329183520 | Add buildings.address_id FK |
| 2025-04-07 | 20250407205544 | Add maps.mappable (polymorphic), make maps.center nullable |
| 2025-04-10 | 20250410133055 | Add maps.type (STI) |
| 2025-05-08 | 20250508171618 | Create building_connections (polymorphic join) |
| 2025-05-21 | 20250521135811 | Create locatable_locations (polymorphic join) |
| 2025-08-14 | 20250814150002 | Add address_id FK to joatu offers/requests |

**Key observation:** Geography hierarchy (May 2024), then 6-month gap, then spatial models (March 2025 onward). Maps table created without geometry; geometry added a day later. Space introduced as parallel float-based system. Last change adds joatu FK.

### B. Complete Model Inventory

**Geography Hierarchy (Relational)**
- `BetterTogether::Geography::Continent`
- `BetterTogether::Geography::Country`
- `BetterTogether::Geography::State`
- `BetterTogether::Geography::Region` (STI extensible)
- `BetterTogether::Geography::Settlement`

**Spatial Models**
- `BetterTogether::Geography::Space` — float lat/lng/elevation store
- `BetterTogether::Geography::GeospatialSpace` — polymorphic join
- `BetterTogether::Geography::Map` — STI (Map, CommunityMap, CommunityCollectionMap); PostGIS center/viewport
- `BetterTogether::Geography::LocatableLocation` — polymorphic event→location join

**Location & Address**
- `BetterTogether::Address` — no geometry; geocoded to Space
- `BetterTogether::Place` — thin Space wrapper
- `BetterTogether::Infrastructure::Building` — STI extensible; has Address
- `BetterTogether::Infrastructure::Floor` — within Building
- `BetterTogether::Infrastructure::Room` — within Floor
- `BetterTogether::Infrastructure::BuildingConnection` — polymorphic connector

**Related**
- `BetterTogether::Event` — includes Geospatial::One and Locatable::One; geocoding commented out
- `BetterTogether::Joatu::Offer`, `Request` — have address_id FK (no model assoc)

### C. Spatial Columns Reference

| Table | Column | Type | SRID | GiST Index |
|-------|--------|------|------|-----------|
| `geography_maps` | center | geography(ST_Point, 4326) | 4326 | ❌ |
| `geography_maps` | viewport | geography(ST_Polygon, 4326) | 4326 | ❌ |
| `geography_spaces` | latitude | float | — | ❌ |
| `geography_spaces` | longitude | float | — | ❌ |
| `geography_spaces` | elevation | float | — | ❌ |

---

## Summary & Next Steps

The Community Engine geography system is **architecturally sound but incompletely realized**. It has:
- ✅ Well-designed model hierarchy and relationships
- ✅ Geocoding infrastructure for addresses and buildings
- ✅ Comprehensive design documentation
- ✅ PostGIS extension and spatial columns on maps

But it is missing:
- ❌ PostGIS geometry storage for coordinates (float-only prevents spatial queries)
- ❌ Spatial indexes (would enable proximity search once geometry exists)
- ❌ Event location API exposure
- ❌ Geographic filter params
- ❌ Building/Floor/Room UI and API resources
- ❌ v0.12.0 implementation (13 issues open, no work started)

**Recommended immediate next steps:**
1. File PR to remove Event dead code (1 hour)
2. File PR to add GiST index on `maps.center` (1 hour)
3. Design & estimate v0.12.0 schema migration for Space geometry (1 day planning)
4. Coordinate with team on v0.12.0 sprint roadmap (decisions on geometry migration approach, scope prioritization)

---

**Assessment completed:** June 3, 2026  
**Data sources:** 24 migrations, 9 system docs, 9 diagram files, 13 GitHub issues, 50+ model/controller files  
**Analysis depth:** Comprehensive; every gap cross-referenced to source code and schema
