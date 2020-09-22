require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Community class
        class CommunityResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Community'

          attributes :name, :description, :slug

          has_one :creator
        end
      end
    end
  end
end
