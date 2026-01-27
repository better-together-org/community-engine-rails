# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the User class for registration
      # Note: This is a write-only resource for user registration
      # Passwords should only be accepted as input, never returned in responses
      class RegistrationResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::User'

        # Only safe attributes that can be returned
        attributes :email
        attribute :confirmed

        has_one :person

        # Virtual attribute for confirmation status
        def confirmed?
          @model.confirmed_at.present?
        end

        # JSONAPI attribute accessor
        def confirmed
          confirmed?
        end

        # NOTE: password and password_confirmation should only be accepted
        # via strong parameters in the controller, never exposed in responses
      end
    end
  end
end
