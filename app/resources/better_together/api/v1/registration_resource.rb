# frozen_string_literal: true

require_dependency 'better_together/api_resource'

module BetterTogether
  module Api
    module V1
      # Serializes the User class
      class RegistrationResource < ::BetterTogether::ApiResource
        model_name BetterTogether.user_class.to_s

        attributes :email, :password, :password_confirmation
      end
    end
  end
end
