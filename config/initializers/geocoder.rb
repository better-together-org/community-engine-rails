# frozen_string_literal: true

# config/initializers/geocoder.rb
Geocoder.configure(
  # Use test lookup in development/test to avoid external API calls
  lookup: Rails.env.production? ? :nominatim : :test,
  always_raise: :all,
  # geocoding service request timeout, in seconds (default 3):
  timeout: 5,

  # set default units to kilometers:
  units: :km,

  # caching (see Caching section below for details):
  cache: Geocoder::CacheStore::Generic.new(Rails.cache, {})
)

# Configure test geocoding results for development/test environments
unless Rails.env.production?
  Geocoder::Lookup::Test.add_stub(
    'New York, NY', [
      {
        'latitude' => 40.7143528,
        'longitude' => -74.0059731,
        'address' => 'New York, NY, USA',
        'state' => 'New York',
        'state_code' => 'NY',
        'country' => 'United States',
        'country_code' => 'US'
      }
    ]
  )

  Geocoder::Lookup::Test.add_stub(
    'San Francisco, CA', [
      {
        'latitude' => 37.7749295,
        'longitude' => -122.4194155,
        'address' => 'San Francisco, CA, USA',
        'state' => 'California',
        'state_code' => 'CA',
        'country' => 'United States',
        'country_code' => 'US'
      }
    ]
  )

  # Default stub for any address not specifically configured
  Geocoder::Lookup::Test.set_default_stub(
    [
      {
        'latitude' => 0.0,
        'longitude' => 0.0,
        'address' => 'Test Address',
        'state' => 'Test State',
        'country' => 'Test Country',
        'country_code' => 'TC'
      }
    ]
  )
end
