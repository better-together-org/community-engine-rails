# Geography System Documentation

## Overview

The Better Together Geography System is a comprehensive location management and mapping architecture that provides hierarchical geographical organization, geocoding capabilities, and spatial data management using PostGIS. The system supports multi-level geographical entities from continents down to addresses, with integrated mapping and location services.

## System Architecture

### Core Components

#### 1. Geographical Hierarchy Models
- **Continent**: Top-level geographical divisions
- **Country**: National-level entities with ISO code support
- **State**: Provincial/state-level divisions with ISO codes
- **Region**: Custom regional divisions within countries/states
- **Settlement**: Cities, towns, and settlement areas

#### 2. Spatial Management
- **Space**: Core coordinate storage with latitude, longitude, elevation
- **GeospatialSpace**: Join table linking entities to spatial coordinates
- **Address**: Structured address information with geocoding
- **LocatableLocation**: Polymorphic location handling for any entity

#### 3. Mapping & Visualization
- **Map**: Interactive map representations with center, zoom, viewport
- **CommunityMap**: Maps associated with communities
- **CommunityCollectionMap**: Maps for community collections

#### 4. Location Services
- **GeocodingJob**: Background geocoding service
- **LocationSelectorController**: Frontend location selection interface

## Key Features

### 1. Hierarchical Organization
```
Continent
├── Country (ISO 3166-1 codes)
│   ├── State (ISO 3166-2 codes)
│   │   ├── Region (custom divisions)
│   │   │   └── Settlement (cities/towns)
│   │   └── Settlement
│   └── Settlement
└── Settlement
```

### 2. Spatial Data Management
- **PostGIS Integration**: Native PostgreSQL spatial extension support
- **Coordinate Storage**: Latitude, longitude, elevation with validation
- **Spatial Indexing**: Optimized geographical queries and proximity searches
- **Geographic Projections**: WGS 84 (SRID 4326) standard coordinate system

### 3. Flexible Location Handling
- **Polymorphic Locations**: Any model can be geo-located
- **Simple Locations**: String-based location names
- **Structured Locations**: Full address or building references
- **Hybrid Approach**: Support for both simple names and detailed addresses

### 4. Geocoding Integration
- **Background Processing**: Asynchronous geocoding via Sidekiq jobs
- **Cache Support**: Geocoding results cached via Rails.cache
- **Error Handling**: Retry logic with exponential backoff
- **Provider Agnostic**: Configurable geocoding services

## Technical Implementation

### Database Schema

#### Geography Tables

**better_together_geography_spaces**
```sql
- id: UUID primary key
- creator_id: UUID reference to creator
- identifier: Unique string identifier
- elevation: Float precision coordinate
- latitude: Float precision coordinate (-90 to 90)
- longitude: Float precision coordinate (-180 to 180)
- properties: JSONB metadata storage
- metadata: JSONB additional data storage
```

**better_together_geography_geospatial_spaces**
```sql
- id: UUID primary key
- geospatial_type: Polymorphic type reference
- geospatial_id: UUID polymorphic reference
- space_id: UUID reference to geography_spaces
- position: Integer ordering
- primary_flag: Boolean for primary location
```

**better_together_geography_maps**
```sql
- id: UUID primary key
- creator_id: UUID reference to creator
- mappable_type: Polymorphic type for mapped entity
- mappable_id: UUID polymorphic reference
- center: PostGIS ST_POINT geographic coordinates
- zoom: Integer zoom level (default 13)
- viewport: PostGIS ST_POLYGON geographic boundary
- metadata: JSONB map configuration data
- type: STI type for map subclasses
```

**better_together_geography_locatable_locations**
```sql
- id: UUID primary key
- creator_id: UUID reference to creator
- locatable_type: Polymorphic type for located entity
- locatable_id: UUID polymorphic reference
- location_type: Polymorphic type for location (Address/Building)
- location_id: UUID polymorphic location reference
- name: String fallback location name
```

#### Hierarchical Geography Tables

**better_together_geography_continents**
```sql
- id: UUID primary key
- identifier: String unique identifier
- community_id: UUID reference to community
- protected: Boolean system protection flag
```

**better_together_geography_countries**
```sql
- id: UUID primary key
- identifier: String unique identifier
- iso_code: String ISO 3166-1 alpha-2 code
- community_id: UUID reference to community
- protected: Boolean system protection flag
```

**better_together_geography_states**
```sql
- id: UUID primary key
- identifier: String unique identifier
- iso_code: String ISO 3166-2 subdivision code
- country_id: UUID reference to country
- community_id: UUID reference to community
- protected: Boolean system protection flag
```

**better_together_addresses**
```sql
- id: UUID primary key
- contact_detail_id: Optional contact reference
- physical: Boolean physical address flag
- postal: Boolean postal address flag
- line1: String primary address line
- line2: String secondary address line
- city_name: String city/locality
- state_province_name: String state/province
- postal_code: String postal/ZIP code
- country_name: String country name
- latitude: Float geocoded latitude
- longitude: Float geocoded longitude
- privacy: Enum privacy level
- primary_flag: Boolean primary address indicator
- label: String address type label
```

### Model Relationships

#### Core Concerns

**Geography::Geospatial::One**
```ruby
# Provides single location capability to any model
included do
  has_one :geospatial_space, as: :geospatial
  has_one :space, through: :geospatial_space
  delegate :latitude, :longitude, :elevation, to: :space
end

def to_leaflet_point
  {
    lat: latitude,
    lng: longitude,
    elevation: elevation,
    label: to_s
  }
end
```

**Geography::Locatable**
```ruby
# Polymorphic location management
has_many :locatable_locations, as: :locatable
accepts_nested_attributes_for :locatable_locations
```

#### Address Model

**Geocoding Integration**
```ruby
class Address < ApplicationRecord
  include Geography::Geospatial::One
  
  geocoded_by :geocoding_string
  
  after_create :schedule_geocoding
  after_update :schedule_geocoding
  
  def geocoding_string
    to_formatted_s(excluded: %i[display_label line2])
  end
  
  def schedule_geocoding
    return unless should_geocode?
    BetterTogether::Geography::GeocodingJob.perform_later(self)
  end
  
  def should_geocode?
    return false if geocoding_string.blank?
    (changed? or !geocoded?)
  end
end
```

#### Map Model

**PostGIS Integration**
```ruby
class Map < ApplicationRecord
  belongs_to :mappable, polymorphic: true, optional: true
  
  validates :center, presence: true
  validates :zoom, numericality: { only_integer: true, greater_than: 0 }
  
  def default_center
    lon = ENV.fetch('DEFAULT_MAP_CENTER_LNG', '-57.9474').to_f
    lat = ENV.fetch('DEFAULT_MAP_CENTER_LAT', '48.9517').to_f
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    factory.point(lon, lat)
  end
  
  def center_for_leaflet
    "#{center.latitude},#{center.longitude}"
  end
end
```

### Geocoding Configuration

**Geocoder Setup**
```ruby
# config/initializers/geocoder.rb
Geocoder.configure(
  always_raise: :all,
  timeout: 5,
  units: :km,
  cache: Geocoder::CacheStore::Generic.new(Rails.cache, {})
)
```

**Background Job Processing**
```ruby
class GeocodingJob < ApplicationJob
  queue_as :geocoding
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  
  def perform(geocodable)
    coords = geocodable.geocode
    geocodable.save if coords
  end
end
```

### Frontend Integration

#### Location Selector Controller (Stimulus)

**Dynamic Location Forms**
```javascript
// app/javascript/controllers/better_together/location_selector_controller.js
export default class extends Controller {
  static targets = [
    "typeSelector",
    "simpleLocation", 
    "addressLocation",
    "buildingLocation"
  ]
  
  toggleLocationType(event) {
    const selectedType = event.target.value
    this.hideAllLocationTypes()
    
    switch(selectedType) {
      case 'simple':
        this.showSimpleLocation()
        break
      case 'address':
        this.showAddressLocation()
        break
      case 'building':
        this.showBuildingLocation()
        break
    }
  }
}
```

## Configuration Options

### Environment Variables

**Default Map Center**
```bash
DEFAULT_MAP_CENTER_LNG=-57.9474  # Default longitude (Corner Brook, NL)
DEFAULT_MAP_CENTER_LAT=48.9517   # Default latitude (Corner Brook, NL)
```

**Geocoding Service**
```bash
GOOGLE_API_KEY=your_api_key      # Google Maps API key (if using Google)
```

### Sidekiq Queue Configuration

**Queue Priorities**
```yaml
# config/sidekiq.yml
:queues:
  - default
  - mailers
  - [geocoding, 3]  # Lower priority for geocoding operations
```

### PostGIS Requirements

**Database Extensions**
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

**Database Adapter**
```ruby
# config/database.yml
development:
  adapter: postgis
  encoding: unicode
  database: better_together_development
```

## Usage Examples

### Creating Geolocated Content

**Adding Location to Events**
```ruby
event = Event.create(
  title: "Community Meetup",
  locatable_locations_attributes: [{
    location_type: 'BetterTogether::Address',
    location_id: address.id
  }]
)

# Alternative: Simple location
event = Event.create(
  title: "Online Meetup",
  locatable_locations_attributes: [{
    name: "Virtual Event Space"
  }]
)
```

**Creating Interactive Maps**
```ruby
map = Geography::Map.create(
  title: "Community Locations",
  mappable: community,
  center: factory.point(-57.9474, 48.9517),
  zoom: 13,
  metadata: {
    style: 'streets',
    markers: true
  }
)
```

### Geocoding Addresses

**Manual Geocoding**
```ruby
address = Address.create(
  line1: "123 Main Street",
  city_name: "Corner Brook",
  state_province_name: "Newfoundland and Labrador",
  country_name: "Canada",
  postal_code: "A2H 1B2"
)

# Geocoding happens automatically via after_create callback
# Or manually: address.geocode
```

### Spatial Queries

**Finding Nearby Locations**
```ruby
# Find addresses within 10km
nearby_addresses = Address.joins(:space)
  .where("ST_DWithin(better_together_geography_spaces.point, ST_Point(?, ?), ?)",
         longitude, latitude, 10000)
```

**Geographic Filtering**
```ruby
# Find events in a specific region
events_in_region = Event.joins(locatable_locations: { location: :space })
  .where(better_together_geography_spaces: { 
    latitude: (lat_min..lat_max),
    longitude: (lng_min..lng_max)
  })
```

## API Endpoints

### Geography Resources

**Maps**
```
GET    /geography/maps           # List maps
POST   /geography/maps           # Create map
GET    /geography/maps/:id       # Show map
PUT    /geography/maps/:id       # Update map
DELETE /geography/maps/:id       # Delete map
```

**Geographical Entities**
```
GET /geography/continents        # List continents
GET /geography/countries         # List countries
GET /geography/states            # List states
GET /geography/regions           # List regions
GET /geography/settlements       # List settlements
```

## Performance Considerations

### Geocoding Optimization

1. **Batch Processing**: Queue multiple addresses together
2. **Cache Strategy**: Long-term caching of geocoded results
3. **Rate Limiting**: Respect API provider limits
4. **Fallback Handling**: Graceful degradation for failed geocoding

### Spatial Indexing

1. **PostGIS Indexes**: Automatic spatial indexing on geography columns
2. **Composite Indexes**: Combined geographic and attribute indexes
3. **Query Optimization**: Use ST_DWithin for distance queries

### Memory Management

1. **Lazy Loading**: Load coordinates only when needed
2. **Pagination**: Limit result sets for large geographical queries
3. **Caching**: Cache expensive spatial calculations

## Security Considerations

### Data Protection

1. **Privacy Levels**: Address privacy controls (private/public/community)
2. **Access Control**: Community-based access restrictions
3. **Data Validation**: Coordinate boundary validation
4. **Input Sanitization**: Geocoding input cleaning

### API Security

1. **Rate Limiting**: Prevent geocoding API abuse
2. **Key Management**: Secure API key storage
3. **Request Validation**: Validate geographical data inputs
4. **Audit Logging**: Track location data changes

## Monitoring & Maintenance

### Geocoding Monitoring

```ruby
# Monitor geocoding success rates
class GeocodingMetrics
  def self.success_rate(period = 24.hours)
    total = GeocodingJob.where(created_at: period.ago..).count
    failed = GeocodingJob.where(created_at: period.ago..)
                        .where('attempts >= ?', 5).count
    ((total - failed).to_f / total * 100).round(2)
  end
end
```

### Data Quality Checks

```ruby
# Find addresses missing coordinates
ungeocoded = Address.where(latitude: nil, longitude: nil)

# Find invalid coordinates
invalid_coords = Space.where(
  'latitude < -90 OR latitude > 90 OR longitude < -180 OR longitude > 180'
)
```

## Troubleshooting

### Common Issues

1. **Geocoding Failures**
   - Check API key validity
   - Verify address format
   - Check rate limits
   - Review error logs

2. **PostGIS Errors**
   - Ensure extension installed
   - Check coordinate validation
   - Verify SRID consistency

3. **Performance Issues**
   - Review spatial indexes
   - Optimize query patterns
   - Check cache configuration

### Debugging Tools

```ruby
# Test geocoding directly
address.geocode
puts address.coordinates

# Check spatial relationships
space.to_leaflet_point

# Validate PostGIS setup
ActiveRecord::Base.connection.execute("SELECT PostGIS_Version();")
```

This geography system provides a robust foundation for location-based features, supporting everything from simple address storage to complex spatial queries and interactive mapping capabilities.
