# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for WebhookEndpoint
      # Allows managing outbound webhook subscriptions via the API
      class WebhookEndpointResource < ApplicationResource
        model_name 'BetterTogether::WebhookEndpoint'

        attributes :name, :url, :description, :events, :active

        # Secret is write-only for security — only returned on create
        attribute :secret

        has_one :person

        filter :active

        # Auto-assign person from current user on create
        before_create do
          _model.person = context[:current_user]&.person
        end

        def self.creatable_fields(context)
          super - [:secret]
        end

        def self.updatable_fields(context)
          super - %i[secret person]
        end

        # Override fetchable_fields to exclude secret from reads
        def fetchable_fields
          super - [:secret]
        end

        def self.records(options = {})
          context = options[:context]
          context[:policy_used]&.call
          user = context&.dig(:current_user)

          if user&.person&.permitted_to?('manage_platform')
            BetterTogether::WebhookEndpoint.all
          elsif user&.person
            BetterTogether::WebhookEndpoint.where(person: user.person)
          else
            BetterTogether::WebhookEndpoint.none
          end
        end
      end
    end
  end
end
