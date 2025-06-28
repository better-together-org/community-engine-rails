# frozen_string_literal: true

# config/initializers/geocoder.rb
Geocoder.configure(
  always_raise: :all,
  # geocoding service request timeout, in seconds (default 3):
  timeout: 5,

  # set default units to kilometers:
  units: :km,

  # caching (see Caching section below for details):
  cache: Geocoder::CacheStore::Generic.new(Rails.cache, {})
)
