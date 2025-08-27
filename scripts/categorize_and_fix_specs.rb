#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to properly categorize and fix test specs based on route permissions

require 'fileutils'

# Controllers that require platform manager authentication
PLATFORM_MANAGER_CONTROLLERS = %w[
  categories_controller_spec.rb
  communities_controller_spec.rb
  content/blocks_controller_spec.rb
  content/page_blocks_controller_spec.rb
  host_dashboard_controller_spec.rb
  metrics/link_click_reports_controller_spec.rb
  metrics/link_click_reports_download_spec.rb
  metrics/page_view_reports_controller_spec.rb
  metrics/page_view_reports_download_spec.rb
  metrics/reports_controller_spec.rb
  navigation_areas_controller_spec.rb
  navigation_items_controller_spec.rb
  pages_controller_spec.rb
  people_controller_spec.rb
  person_community_memberships_controller_spec.rb
  platforms_controller_spec.rb
  platform_invitations_controller_spec.rb
  resource_permissions_controller_spec.rb
  roles_controller_spec.rb
  users_controller_spec.rb
  geography/continents_controller_spec.rb
  geography/countries_controller_spec.rb
  geography/regions_controller_spec.rb
  geography/region_settlements_controller_spec.rb
  geography/settlements_controller_spec.rb
  geography/states_controller_spec.rb
].freeze

# Controllers that require regular user authentication
USER_AUTHENTICATED_CONTROLLERS = %w[
  agreements_controller_spec.rb
  calendars_controller_spec.rb
  calls_for_interest_controller_spec.rb
  conversations_controller_spec.rb
  events_controller_spec.rb
  help_preferences_controller_spec.rb
  hub_controller_spec.rb
  messages_controller_spec.rb
  navigation_items_controller_spec.rb
  notifications_controller_spec.rb
  person_blocks_controller_spec.rb
  posts_controller_spec.rb
  reports_controller_spec.rb
  search_controller_spec.rb
  settings_controller_spec.rb
  translations_controller_spec.rb
  joatu/offers_controller_spec.rb
  joatu/requests_controller_spec.rb
  joatu/agreements_controller_spec.rb
  joatu/categories_controller_spec.rb
  joatu/hub_controller_spec.rb
  joatu/response_links_controller_spec.rb
].freeze

# Controllers that should run without authentication
NO_AUTH_CONTROLLERS = %w[
  application_controller_spec.rb
  static_pages_controller_spec.rb
  uploads_controller_spec.rb
  wizard_steps_controller_spec.rb
  setup_wizard_controller_spec.rb
  setup_wizard_steps_controller_spec.rb
  metrics/link_clicks_controller_spec.rb
  metrics/page_views_controller_spec.rb
  metrics/search_queries_controller_spec.rb
  metrics/shares_controller_spec.rb
  pages_controller_spec.rb
].freeze

# Special cases that need custom handling
SPECIAL_CASES = %w[
  users/confirmations_controller_spec.rb
  users/passwords_controller_spec.rb
  users/registrations_controller_spec.rb
  users/sessions_controller_spec.rb
].freeze

def determine_auth_type(file_path)
  return :platform_manager if PLATFORM_MANAGER_CONTROLLERS.any? { |controller| file_path.include?(controller) }
  return :user if USER_AUTHENTICATED_CONTROLLERS.any? { |controller| file_path.include?(controller) }
  return :none if NO_AUTH_CONTROLLERS.any? { |controller| file_path.include?(controller) }
  return :special if SPECIAL_CASES.any? { |controller| file_path.include?(controller) }

  # Default fallback - analyze content
  content = File.read(file_path)
  if content.include?('login(\'manager@') || content.include?('login_as_platform_manager')
    :platform_manager
  elsif content.include?('login(') || content.include?('login_as_user')
    :user
  else
    :none
  end
end

def process_file(file_path)
  content = File.read(file_path)
  original_content = content.dup

  # Skip files that already have automatic configuration
  return if content.include?(':as_platform_manager') || content.include?(':as_user')

  auth_type = determine_auth_type(file_path)

  case auth_type
  when :platform_manager
    # Clean up existing manual config
    content = clean_manual_auth(content)
    content = add_auth_tag(content, ':as_platform_manager')

  when :user
    # Clean up existing manual config
    content = clean_manual_auth(content)
    content = add_auth_tag(content, ':as_user')

  when :none
    # Just clean up manual config, no auth tag needed
    content = clean_manual_auth(content)

  when :special
    puts "⚠️  Skipping special case: #{file_path} (needs manual review)"
    return
  end

  if content == original_content
    puts "➡️  No changes needed: #{file_path}"
  else
    File.write(file_path, content)
    puts "✅ Updated #{auth_type}: #{file_path}"
  end
end

def clean_manual_auth(content)
  # Remove manual before blocks with authentication
  content.gsub!(
    /^\s*before do\s*\n(\s*configure_host_platform\s*\n)?(\s*logout\([^)]*\)\s*\n)?(\s*login[^)]*\)\s*\n)*\s*end\s*\n/m, ''
  )

  # Remove standalone authentication calls
  content.gsub!(/^\s*configure_host_platform\s*\n/, '')
  content.gsub!(/^\s*logout\([^)]*\)\s*\n/, '')
  content.gsub!(/^\s*login[^)]*\)\s*\n/, '')

  content
end

def add_auth_tag(content, tag)
  # Add authentication tag to RSpec.describe line
  if content =~ /^(\s*RSpec\.describe\s+[^,\n]+)(\s+do|\s*$)/
    content.gsub(/^(\s*RSpec\.describe\s+[^,\n]+?)(\s+do|\s*$)/) do
      "#{Regexp.last_match(1)}, #{tag}#{Regexp.last_match(2)}"
    end
  else
    content
  end
end

# Process all request and controller specs
spec_types = %w[requests controllers]
spec_types.each do |spec_type|
  pattern = "spec/#{spec_type}/**/*_spec.rb"
  Dir.glob(pattern).each do |file_path|
    process_file(file_path)
  end
end

# Handle feature specs separately as they may need context-based auth
feature_pattern = 'spec/features/**/*_spec.rb'
Dir.glob(feature_pattern).each do |file_path|
  content = File.read(file_path)

  if content.include?(':as_platform_manager') || content.include?(':as_user')
    puts "➡️  Feature spec already configured: #{file_path}"
    next
  end

  # For feature specs, determine based on the feature being tested
  auth_type = determine_auth_type(file_path)

  case auth_type
  when :platform_manager
    content = clean_manual_auth(content)
    content = add_auth_tag(content, ':as_platform_manager')
  when :user
    content = clean_manual_auth(content)
    content = add_auth_tag(content, ':as_user')
  when :none
    content = clean_manual_auth(content)
  else
    puts "⚠️  Feature spec needs manual review: #{file_path}"
    next
  end

  File.write(file_path, content)
  puts "✅ Updated feature #{auth_type}: #{file_path}"
end

puts '🎉 Categorization and fixing complete!'
