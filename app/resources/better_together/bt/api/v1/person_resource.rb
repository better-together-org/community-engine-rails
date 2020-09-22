require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Person class
        class PersonResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Person'

          attributes :name, :description, :slug

          filters :name
        end
      end
    end
  end
end
