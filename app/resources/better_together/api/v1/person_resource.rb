# frozen_string_literal: true

require_dependency 'better_together/api_resource'

module BetterTogether
  module Api
    module V1
      # Serializes the Person class
      class PersonResource < ::BetterTogether::ApiResource
        model_name '::BetterTogether::Person'

        attributes :name, :description, :slug
      end
    end
  end
end
