#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to refactor test specs to use automatic test configuration

require 'fileutils'

# Define patterns for different types of authentication
PLATFORM_MANAGER_PATTERNS = [
  /login\('manager@example\.test'/,
  /login_as_platform_manager/,
  /login\('manager@/
].freeze

USER_PATTERNS = [
  /login\('user@example\.test'/,
  /login_as_user/,
  /login_as\(user/
].freeze

def process_file(file_path)
  content = File.read(file_path)
  original_content = content.dup

  # Skip files that already have automatic configuration
  return if content.include?(':as_platform_manager') || content.include?(':as_user')

  # Skip specific files that need manual handling
  skip_files = [
    'setup_wizard_spec.rb',
    'platform_invitation_accept_spec.rb',
    'registration_spec.rb'
  ]
  return if skip_files.any? { |skip| file_path.include?(skip) }

  # Determine authentication type
  auth_tag = nil
  if PLATFORM_MANAGER_PATTERNS.any? { |pattern| content.match?(pattern) }
    auth_tag = ':as_platform_manager'
  elsif USER_PATTERNS.any? { |pattern| content.match?(pattern) }
    auth_tag = ':as_user'
  end

  return unless auth_tag

  # Remove manual configuration blocks
  content.gsub!(
    /^\s*before do\s*\n(\s*configure_host_platform\s*\n)?(\s*logout\([^)]*\)\s*\n)?(\s*login[^)]*\)\s*\n)*\s*end\s*\n/m, ''
  )
  content.gsub!(/^\s*configure_host_platform\s*\n/, '')
  content.gsub!(/^\s*logout\([^)]*\)\s*\n/, '')
  content.gsub!(/^\s*login[^)]*\)\s*\n/, '')

  # Add authentication tag to RSpec.describe line
  if content =~ /^(RSpec\.describe\s+[^,\n]+)(\s+do|\s*$)/
    content.gsub!(/^(RSpec\.describe\s+[^,\n]+)(\s+do|\s*$)/) do
      "#{Regexp.last_match(1)}, #{auth_tag}#{Regexp.last_match(2)}"
    end
  end

  # Write back if changed
  return unless content != original_content

  File.write(file_path, content)
  puts "✅ Updated: #{file_path}"
end

# Process all request, controller, and feature specs
spec_types = %w[requests controllers features]
spec_types.each do |spec_type|
  pattern = "spec/#{spec_type}/**/*_spec.rb"
  Dir.glob(pattern).each do |file_path|
    process_file(file_path)
  end
end

puts '🎉 Refactoring complete!'
