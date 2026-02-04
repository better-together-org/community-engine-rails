# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the User class for API responses
      # SECURITY: Never expose password fields in API responses
      class UserResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::User'

        # Safe attributes only
        attributes :email
        attribute :confirmed

        # Relationships
        has_one :person

        # Virtual attribute for confirmation status
        def confirmed?
          @model.confirmed_at.present?
        end

        # JSONAPI attribute accessor
        # rubocop:disable Naming/PredicateMethod
        def confirmed
          confirmed?
        end
        # rubocop:enable Naming/PredicateMethod
      end
    end
  end
end
