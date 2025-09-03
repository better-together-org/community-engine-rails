# frozen_string_literal: true

require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the User class
        class UserResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::User'

          attributes :email, :password, :password_confirmation
        end
      end
    end
  end
end
