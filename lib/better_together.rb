# frozen_string_literal: true

require 'better_together/version'
require 'better_together/adapter_registry'
require 'better_together/engine'
require 'better_together/sitemap_helper'
require 'better_together/mcp'

# Convenience setters and getters for the engine
module BetterTogether
  mattr_accessor :base_url,
                 :adapter_registry,
                 :new_user_password_path,
                 :route_scope_path,
                 :user_class,
                 :user_confirmation_path

  # Thread-safe flag to skip navigation touch callbacks during bulk operations
  thread_mattr_accessor :skip_navigation_touches
  self.skip_navigation_touches = false

  # Host app extension: proc evaluated inside `namespace :v1 do` in the engine routes.
  # Usage in host app initializer:
  #   BetterTogether.api_v1_routes_extension = proc do
  #     jsonapi_resources :wayfinders
  #   end
  mattr_accessor :api_v1_routes_extension

  # Additional OpenAPI/Swagger endpoints to register in the rswag UI.
  # Usage: BetterTogether.swagger_additional_endpoints << ['/my-app/api/docs/v1/swagger.yaml', 'My App API V1']
  mattr_accessor :swagger_additional_endpoints
  self.swagger_additional_endpoints = []
  self.adapter_registry = BetterTogether::AdapterRegistry.new

  ADAPTER_GROUPS = %i[
    error_reporting
    search
    metrics
    publishing
    translation
    mapping
    federation
  ].freeze

  class << self
    def register_adapter(group, name = nil, adapter = nil, &)
      adapter_registry.register(group, name, adapter, &)
    end

    def adapters_for(group)
      adapter_registry.adapters_for(group)
    end

    def clear_adapters!(group = nil)
      adapter_registry.clear!(group)
    end

    def dispatch_to_adapters(group, *, **)
      adapter_registry.dispatch(group, *, **)
    end

    def register_error_reporter(name = nil, reporter = nil, &block)
      adapter = reporter || block
      register_adapter(:error_reporting, name, adapter)
    end

    def clear_error_reporters!
      clear_adapters!(:error_reporting)
    end

    def report_error(exception, context: {})
      return default_error_reporter(exception, context:) if adapters_for(:error_reporting).blank?

      dispatch_to_adapters(:error_reporting, exception, context:)
    end

    def e2ee_messaging_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('BETTER_TOGETHER_E2EE_MESSAGING_ENABLED', nil)) == true
    end

    def base_path
      BetterTogether::Engine.routes.find_script_name({})
    end

    def base_path_with_locale(locale: I18n.locale)
      "#{base_path}#{locale}"
    end

    def base_url_with_locale(locale: I18n.locale)
      "#{base_url}/#{locale}"
    end

    def route_scope_path
      @@route_scope_path || 'bt'
    end

    def new_user_password_url
      base_url + new_user_password_path
    end

    def new_user_password_path
      return @@new_user_password_path if @@new_user_password_path.present?

      ::BetterTogether::Engine.routes.url_helpers.new_user_password_path(locale: I18n.locale)
    end

    def user_class
      @@user_class.constantize
    end

    def user_confirmation_path
      return @@user_confirmation_path if @@user_confirmation_path.present?

      ::BetterTogether::Engine.routes.url_helpers.user_confirmation_path(locale: I18n.locale)
    end

    def user_confirmation_url
      base_url + user_confirmation_path
    end

    private

    def default_error_reporter(exception, context: {})
      return unless defined?(Rails) && Rails.respond_to?(:error) && Rails.error.respond_to?(:report)

      Rails.error.report(exception, handled: true, severity: :error, context:)
    end
  end
end
