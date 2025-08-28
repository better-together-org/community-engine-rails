# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
  include FactoryBot::Syntax::Methods

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

  # Some example descriptions need elevated auth to exercise data owned by a manager
  SPECIAL_MANAGER_DESCRIPTIONS = [
    'aggregated matches'
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

    # Heuristic: allow Setup Wizard feature specs to run without auto host setup
    if example.metadata[:type] == :feature
      full_description = [
        example.example_group.description,
        example.example_group.parent_groups.map(&:description)
      ].flatten.compact.join(' ').downcase

      return if full_description.include?('setup wizard')
    end

    configure_host_platform
  end

  def configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public')
    else
      host_platform = create(:better_together_platform, :host, privacy: 'public')
    end

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')

    unless platform_manager
      create(
        :user, :confirmed, :platform_manager,
        email: 'manager@example.test',
        password: 'password12345'
      )
    end

    host_platform
  end

  def setup_authentication_if_needed(example)
    # Skip auto-authentication for Setup Wizard feature specs so the wizard is reachable
    if feature_spec_type?(example)
      full_description = [
        example.example_group.description,
        example.example_group.parent_groups.map(&:description)
      ].flatten.compact.join(' ').downcase

      # Avoid auto-login for flows that require being logged out
      return if full_description.match?(/setup wizard|invitation|sign up|register|registration/)
    end

    # Check for explicit tags first
    if example.metadata[:as_platform_manager] || example.metadata[:platform_manager]
      use_auth_method_for_spec_type(example, :manager)
    elsif example.metadata[:as_user] || example.metadata[:authenticated] || example.metadata[:user]
      use_auth_method_for_spec_type(example, :user)
    elsif example.metadata[:no_auth] || example.metadata[:unauthenticated]
      # Explicitly ensure no authentication - session already cleaned by ensure_clean_session
      nil
    else
      # Check description-based inference
      full_description = [
        example.example_group.description,
        example.example_group.parent_groups.map(&:description)
      ].flatten.compact.join(' ').downcase

      if MANAGER_KEYWORDS.any? { |keyword| full_description.include?(keyword) } ||
         SPECIAL_MANAGER_DESCRIPTIONS.any? { |keyword| full_description.include?(keyword) }
        use_auth_method_for_spec_type(example, :manager)
      elsif USER_KEYWORDS.any? { |keyword| full_description.include?(keyword) }
        use_auth_method_for_spec_type(example, :user)
      elsif feature_spec_type?(example) # rubocop:todo Lint/DuplicateBranch
        # Sensible default for feature specs: authenticate as a regular user
        use_auth_method_for_spec_type(example, :user)
      end
    end
  end

  # Use the appropriate authentication method based on the spec type
  def use_auth_method_for_spec_type(example, user_type)
    # Avoid HTTP logout for request specs to prevent creating a response object
    logout if (feature_spec_type?(example) || controller_spec_type?(example)) && respond_to?(:logout)

    if controller_spec_type?(example)
      # Use Devise test helpers for controller specs
      user = if user_type == :manager
               find_or_create_test_user('manager@example.test', 'password12345', :platform_manager)
             else
               find_or_create_test_user('user@example.test', 'password12345', :user)
             end
      sign_in user
    elsif feature_spec_type?(example)
      # Use Capybara navigation for feature specs
      extend BetterTogether::CapybaraFeatureHelpers unless respond_to?(:capybara_login_as_platform_manager)
      # Ensure the target user exists before attempting a UI login
      if user_type == :manager
        find_or_create_test_user('manager@example.test', 'password12345', :platform_manager)
        capybara_login_as_platform_manager
        # Navigate to context-appropriate page when helpful
        full_description = [
          example.example_group.description,
          example.example_group.parent_groups.map(&:description)
        ].flatten.compact.join(' ').downcase
        if full_description.include?('creating a new conversation')
          visit new_conversation_path(locale: I18n.default_locale)
        end
      else
        find_or_create_test_user('user@example.test', 'password12345', :user)
        capybara_login_as_user
      end
    else
      # Request specs: choose auth mechanism based on description
      user = if user_type == :manager
               find_or_create_test_user('manager@example.test', 'password12345', :platform_manager)
             else
               find_or_create_test_user('user@example.test', 'password12345', :user)
             end

      full_description = [
        example.example_group.description,
        example.example_group.parent_groups.map(&:description)
      ].flatten.compact.join(' ')

      # Keep response nil for Example Automatic Configuration showcase; otherwise ensure route constraints by HTTP login
      if full_description.include?('Example Automatic Configuration') && respond_to?(:sign_in)
        sign_in user
      else
        login(user.email, 'password12345')
      end
    end
  end

  # Detect if we're in a controller spec (which needs Devise helpers)
  def controller_spec_type?(example = nil)
    # Check the example metadata if provided
    return example.metadata[:type] == :controller if example

    # Fallback: try to detect from context
    respond_to?(:controller) &&
      ((defined?(@controller) && @controller.present?) ||
       (respond_to?(:described_class) && described_class&.to_s&.include?('Controller')))
  end

  # Detect if we're in a feature spec (which needs Capybara helpers)
  def feature_spec_type?(example = nil)
    # Check the example metadata if provided
    return example.metadata[:type] == :feature if example

    # Fallback: try to detect from context (feature specs have Capybara methods)
    respond_to?(:visit) && respond_to?(:page)
  end

  def find_or_create_test_user(email, password, role_type = :user)
    user = BetterTogether::User.find_by(email: email)
    unless user
      user = FactoryBot.create(:better_together_user, :confirmed, email: email, password: password)
      if role_type == :platform_manager
        platform = BetterTogether::Platform.first
        role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        if platform && role
          BetterTogether::PlatformMembership.create!(
            member: user.person,
            platform: platform,
            role: role
          )
        end
      end
    end
    user
  end

  def ensure_clean_session
    # Ensure session is completely clean between tests
    # Avoid HTTP logout in request/feature specs to prevent creating a response object
    # Session cleanup below + Warden reset is sufficient
    reset_session if respond_to?(:reset_session)

    # Clear any Warden authentication data
    @request&.env&.delete('warden') if respond_to?(:request) && defined?(@request)
  end
end

RSpec.configure do |config|
  # Include the helper methods in all specs
  config.include AutomaticTestConfiguration

  # Set up automatic configuration for request, controller, and feature specs
  config.before(:each, type: :request) do |example|
    ensure_clean_session
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  config.after(:each, type: :request) do
    ensure_clean_session
  end

  config.before(:each, type: :controller) do |example|
    ensure_clean_session
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  config.after(:each, type: :controller) do
    ensure_clean_session
  end

  config.before(:each, type: :feature) do |example|
    ensure_clean_session
    setup_host_platform_if_needed(example)
    setup_authentication_if_needed(example)
  end

  config.after(:each, type: :feature) do
    ensure_clean_session
  end

  # Run certain navigation steps after example-level lets have been evaluated
  config.append_before(:each, type: :feature) do |example|
    full_description = [
      example.example_group.description,
      example.example_group.parent_groups.map(&:description)
    ].flatten.compact.join(' ').downcase

    if full_description.include?('creating a new conversation') && example.metadata[:as_platform_manager]
      visit new_conversation_path(locale: I18n.default_locale)
    end
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

# rubocop:enable Metrics/ModuleLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
