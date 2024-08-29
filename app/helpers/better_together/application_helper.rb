# frozen_string_literal: true

module BetterTogether
  # Provides helper methods used across the BetterTogether engine.
  # These methods facilitate access to common resources like the current user,
  # platform configurations, and navigation items.
  module ApplicationHelper
    # Returns the base URL configured for BetterTogether.
    def base_url
      ::BetterTogether.base_url
    end

    # Returns the base path configured for BetterTogether.
    def base_path
      ::BetterTogether.base_path
    end

    # Returns the base path configured for BetterTogether plus the locale.
    def base_path_with_locale
      ::BetterTogether.base_path_with_locale
    end

    # Returns the current active identity for the user.
    # This is a placeholder and should be updated to support active identity features.
    def current_identity
      @current_identity ||= current_person
    end

    # Retrieves the current person associated with the signed-in user.
    # Returns nil if no user is signed in or the user has no associated person.
    def current_person
      return unless user_signed_in? && current_user.person

      @current_person ||= current_user.person
    end

    # Finds the platform marked as host or returns a new default host platform instance.
    # This method ensures there is always a host platform available, even if not set in the database.
    def host_platform
      @host_platform ||= ::BetterTogether::Platform.find_by(host: true) ||
                         ::BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url)
    end

    # Finds the community marked as host or returns a new default host community instance.
    def host_community
      @host_community ||= ::BetterTogether::Community.find_by(host: true) ||
                          ::BetterTogether::Community.new(name: 'Better Together')
    end

    # Retrieves the setup wizard for hosts or raises an error if not found.
    # This is crucial for initial setup processes and should be pre-configured.
    def host_setup_wizard
      @host_setup_wizard ||= ::BetterTogether::Wizard.find_by(identifier: 'host_setup') ||
                             raise(StandardError, 'Host Setup Wizard not configured. Please run rails db:seed')
    end

    def locale_options_for_select(selected_locale = I18n.locale)
      options_for_select(
        I18n.available_locales.map { |locale| [I18n.t("locales.#{locale}", locale:), locale] },
        selected_locale
      )
    end

    # Handles missing method calls for route helpers related to BetterTogether.
    # This allows for cleaner calls to named routes without prefixing with 'better_together.'
    def method_missing(method, *, &) # rubocop:todo Style/MissingRespondToMissing
      if better_together_url_helper?(method)
        better_together.send(method, *)
      else
        super
      end
    end

    # Checks if a method can be responded to, especially for dynamic route helpers.
    def respond_to?(method, include_all = false) # rubocop:todo Style/OptionalBooleanParameter
      better_together_url_helper?(method) || super
    end

    private

    # Checks if a method name corresponds to a missing URL or path helper for BetterTogether.
    def better_together_url_helper?(method)
      method.to_s.end_with?('_path', '_url') && better_together.respond_to?(method)
    end
  end
end
