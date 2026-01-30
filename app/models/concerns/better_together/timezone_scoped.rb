# frozen_string_literal: true

module BetterTogether
  # Unified timezone handling concern for controllers, mailers, jobs, and MCP
  # Provides consistent timezone resolution across all contexts
  #
  # Priority hierarchy (first available wins):
  # 1. Explicit timezone parameter (for targeted operations)
  # 2. Recipient/user timezone (for user-specific operations)
  # 3. Platform timezone (platform-wide default)
  # 4. Application config timezone
  # 5. UTC (fallback)
  #
  # @example In a controller
  #   class MyController < ApplicationController
  #     include BetterTogether::TimezoneScoped
  #     around_action :with_timezone_scope
  #
  #     def show
  #       # Time.zone is automatically set to user/platform timezone
  #       @event_time = @event.starts_at.in_time_zone
  #     end
  #   end
  #
  # @example In a mailer
  #   class MyMailer < ApplicationMailer
  #     include BetterTogether::TimezoneScoped
  #
  #     def welcome_email(recipient)
  #       @recipient = recipient
  #       with_timezone_scope(recipient: @recipient) do
  #         mail(to: @recipient.email, subject: 'Welcome')
  #       end
  #     end
  #   end
  #
  # @example In a job
  #   class MyJob < ApplicationJob
  #     include BetterTogether::TimezoneScoped
  #
  #     def perform(user)
  #       with_timezone_scope(user: user) do
  #         # Process in user's timezone
  #       end
  #     end
  #   end
  #
  # @example In an MCP tool
  #   class MyTool < ApplicationTool
  #     include BetterTogether::TimezoneScoped
  #
  #     def call
  #       with_timezone_scope do
  #         # Uses current_user's timezone automatically
  #       end
  #     end
  #   end
  module TimezoneScoped
    extend ActiveSupport::Concern

    # Execute block within appropriate timezone context
    # @param timezone [String, nil] Explicit timezone to use (IANA identifier)
    # @param user [User, nil] User whose timezone to use
    # @param recipient [Person, User, nil] Recipient whose timezone to use
    # @param platform [Platform, nil] Platform whose timezone to use
    # @yield Block to execute in timezone context
    def with_timezone_scope(timezone: nil, user: nil, recipient: nil, platform: nil, &)
      tz = resolve_timezone(timezone: timezone, user: user, recipient: recipient, platform: platform)
      Time.use_zone(tz, &)
    end

    # Resolve timezone from available sources following priority hierarchy
    # @param timezone [String, nil] Explicit timezone override
    # @param user [User, nil] User with timezone preference
    # @param recipient [Person, User, nil] Recipient with timezone preference
    # @param platform [Platform, nil] Platform with timezone setting
    # @return [String] IANA timezone identifier
    def resolve_timezone(timezone: nil, user: nil, recipient: nil, platform: nil)
      # 1. Explicit timezone parameter (highest priority)
      return timezone if timezone.present?

      # 2. Recipient timezone (for recipient-specific operations like emails)
      recipient_tz = extract_timezone_from_recipient(recipient)
      return recipient_tz if recipient_tz

      # 3. User timezone (for user-specific operations)
      # If no explicit user provided, try current_user in controller/MCP context
      user_tz = extract_timezone_from_user(user) || (user.nil? ? current_user_timezone : nil)
      return user_tz if user_tz

      # 4. Platform timezone (platform-wide default)
      # In MCP/controller contexts, automatically use host platform if no platform specified
      platform_tz = extract_timezone_from_platform(platform || (in_request_context? ? :host : nil))
      return platform_tz if platform_tz

      # 5. Application config timezone
      app_tz = Rails.application.config.time_zone.presence
      return app_tz if app_tz

      # 6. UTC fallback
      'UTC'
    end

    private

    # Check if we're in a request context (controller or MCP tool)
    # @return [Boolean] true if in request context
    def in_request_context?
      # MCP tools have current_user method
      respond_to?(:current_user, true) ||
        # Controllers have helpers
        respond_to?(:helpers, true) ||
        # Check if we respond to request (both controllers and MCP tools have this)
        respond_to?(:request, true)
    end

    # Extract timezone from recipient (Person or User)
    # @param recipient [Person, User, nil] The recipient
    # @return [String, nil] IANA timezone or nil
    def extract_timezone_from_recipient(recipient)
      return nil unless recipient

      if recipient.respond_to?(:time_zone)
        recipient.time_zone.presence
      elsif recipient.respond_to?(:person) && recipient.person.respond_to?(:time_zone)
        recipient.person.time_zone.presence
      end
    end

    # Extract timezone from user
    # @param user [User, nil] The user
    # @return [String, nil] IANA timezone or nil
    def extract_timezone_from_user(user)
      return nil unless user
      return current_user_timezone if user == :current && respond_to?(:current_user, true)

      if user.respond_to?(:person) && user.person&.time_zone.present?
        user.person.time_zone
      elsif user.respond_to?(:time_zone)
        user.time_zone.presence
      end
    end

    # Extract timezone from platform
    # @param platform [Platform, nil] The platform
    # @return [String, nil] IANA timezone or nil
    def extract_timezone_from_platform(platform)
      return nil unless platform
      return host_platform_timezone if platform == :host

      platform.time_zone.presence if platform.respond_to?(:time_zone)
    end

    # Get timezone from current user in controller/MCP context
    # @return [String, nil] IANA timezone or nil
    def current_user_timezone
      return nil unless respond_to?(:current_user, true)

      user = current_user
      return nil unless user

      user.person&.time_zone.presence || user.time_zone.presence
    end

    # Get timezone from host platform
    # @return [String, nil] IANA timezone or nil
    def host_platform_timezone
      # Try controller helper first
      if respond_to?(:helpers, true) && helpers.respond_to?(:host_platform)
        return helpers.host_platform&.time_zone.presence
      end

      # Fall back to direct lookup
      BetterTogether::Platform.find_by(host: true)&.time_zone.presence
    end

    # Alias methods for compatibility with existing code
    included do
      # Alias for with_timezone_scope for controllers
      alias_method :set_time_zone, :with_timezone_scope if method_defined?(:set_time_zone)

      # Provide determine_timezone for backwards compatibility
      def determine_timezone(timezone: nil, user: nil, recipient: nil, platform: nil)
        resolve_timezone(timezone: timezone, user: user, recipient: recipient, platform: platform)
      end
    end
  end
end
