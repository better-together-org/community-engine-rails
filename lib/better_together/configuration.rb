# frozen_string_literal: true

module BetterTogether
  # Convenience configurator for the engine
  class Configuration
    attr_reader :base_url,
                :adapter_registry,
                :new_user_password_path,
                :user_class,
                :user_confirmation_path

    delegate :base_url=, to: :BetterTogether

    delegate :content_safety_orchestrator_command=, to: :BetterTogether

    delegate :inbound_email_ingress_password=, to: :BetterTogether
    delegate :adapters_for, :clear_adapters!, :clear_error_reporters!, :dispatch_to_adapters,
             :register_adapter, :register_error_reporter, to: :BetterTogether

    delegate :adapter_registry=, to: :BetterTogether

    delegate :content_safety_orchestrator_command=, to: :BetterTogether

    delegate :new_user_password_path=, to: :BetterTogether

    delegate :user_class=, to: :BetterTogether

    delegate :user_confirmation_path=, to: :BetterTogether

    delegate :api_v1_routes_extension=, to: :BetterTogether

    delegate :swagger_additional_endpoints=, to: :BetterTogether
  end
end
