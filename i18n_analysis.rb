#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance analysis script for I18n JavaScript optimization
require 'json'

# Simulating the current approach - loading all translations
full_translations = {
  'better_together' => {
    'device_permissions' => {
      'status' => { 'granted' => 'Granted', 'denied' => 'Denied', 'unknown' => 'Unknown' },
      'location' => { 'denied' => 'Location denied', 'enabled' => 'Location enabled', 'unsupported' => 'Not supported' }
    },
    'navigation' => { 'home' => 'Home', 'about' => 'About' }, # ... hundreds more keys
    'forms' => { 'submit' => 'Submit', 'cancel' => 'Cancel' }, # ... hundreds more keys
    # Simulate ~2000 translation keys
    **1000.times.to_h { |i| ["key_#{i}", "Value #{i}"] }
  }
}

# Optimized approach - only JS-needed translations
selective_translations = {
  'better_together' => {
    'device_permissions' => {
      'status' => { 'granted' => 'Granted', 'denied' => 'Denied', 'unknown' => 'Unknown' },
      'location' => { 'denied' => 'Location denied', 'enabled' => 'Location enabled', 'unsupported' => 'Not supported' }
    }
  }
}

full_json = full_translations.to_json
selective_json = selective_translations.to_json

puts '=== I18n JavaScript Optimization Analysis ==='

full_kb = (full_json.bytesize / 1024.0).round(2)
selective_kb = (selective_json.bytesize / 1024.0).round(2)

puts "Full translation payload size: #{full_json.bytesize} bytes (#{full_kb} KB)"
puts "Selective translation payload size: #{selective_json.bytesize} bytes (#{selective_kb} KB)"
puts "Size reduction: #{((1 - (selective_json.bytesize.to_f / full_json.bytesize)) * 100).round(2)}%"
puts "Estimated real-world savings: #{(((2000 * 50) - (6 * 50)) / 1024.0).round(2)} KB"
