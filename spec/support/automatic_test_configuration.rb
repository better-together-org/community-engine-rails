# frozen_string_literal: true

# Automatic Test Configuration
#
# This module provides automatic setup for request, controller, and feature tests:
# 1. Host platform configuration (unless :skip_host_setup tag is present)
# 2. Automatic authentication based on tags or test descriptions
#
# Usage:
# - By default, all request/controller/feature tests get host platform setup
# - Use :skip_host_setup tag to skip host platform configuration
# - Use :as_platform_manager tag to login as platform manager
# - Use :as_user tag to login as regular user
# - Use :authenticated tag to login as default user
# - Authentication is also inferred from describe/context blocks containing:
#   - "platform manager", "admin", "manager"
#   - "authenticated", "logged in", "signed in"

module AutomaticTestConfiguration
  extend ActiveSupport::Concern

  # Keywords that trigger automatic platform manager authentication
  MANAGER_KEYWORDS = [
    'platform manager',
    'admin',
    'manager',
    'host admin',
    'system admin'
  ].freeze

  # Keywords that trigger automatic user authentication
  USER_KEYWORDS = [
    'authenticated',
    'logged in',
    'signed in',
    'user',
    'member'
  ].freeze

  module ClassMethods
    # Configure automatic authentication based on describe/context text
    def auto_authenticate_from_description(description)
      description_lower = description.downcase

      if MANAGER_KEYWORDS.any? { |keyword| description_lower.include?(keyword) }
        metadata[:as_platform_manager] = true
      elsif USER_KEYWORDS.any? { |keyword| description_lower.include?(keyword) }
        metadata[:as_user] = true
      end
    end
  end

  private

  def setup_host_platform_if_needed(example)
    return if example.metadata[:skip_host_setup]
    return if example.metadata[:type] == :model

    configure_host_platform
  end

  def setup_authentication_if_needed(example)
    # Check for explicit tags first
    if example.metadata[:as_platform_manager] || example.metadata[:platform_manager]
      login_as_platform_manager
    elsif example.metadata[:as_user] || example.metadata[:authenticated] || example.metadata[:user]
      login_as_user
    elsif example.metadata[:no_auth] || example.metadata[:unauthenticated]
      # Explicitly no authentication
      logout(:user) if respond_to?(:logout)
    else
      # Check description-based inference
      full_description = [
        example.example_group.description,
        example.example_group.parent_groups.map(&:description)
      ].flatten.compact.join(' ').downcase

      if MANAGER_KEYWORDS.any? { |keyword| full_description.include?(keyword) }
        login_as_platform_manager
      elsif USER_KEYWORDS.any? { |keyword| full_description.include?(keyword) }
        login_as_user
      end
    end
  end

  def login_as_platform_manager
    logout(:user) if respond_to?(:logout)
    login('manager@example.test', 'password12345')
  end

  def login_as_user
    logout(:user) if respond_to?(:logout)
    login('user@example.test', 'password12345')
  end
end

RSpec.configure do |config|
  # Include the helper methods in all specs
  config.include AutomaticTestConfiguration

  # Set up automatic configuration for request, controller, and feature specs
  config.before(:each, type: :request) do |example|
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  config.before(:each, type: :controller) do |example|
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  config.before(:each, type: :feature) do |example|
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  # Extend RSpec DSL to support description-based auto-authentication
  config.extend(Module.new do
    def describe(*args, **options, &)
      super do
        # Analyze the description for authentication keywords
        description = args.first.to_s
        auto_authenticate_from_description(description)

        instance_eval(&)
      end
    end

    def context(*args, **options, &)
      super do
        # Analyze the context description for authentication keywords
        description = args.first.to_s
        auto_authenticate_from_description(description)

        instance_eval(&)
      end
    end
  end)
end
