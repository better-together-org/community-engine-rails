require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Community class
        class CommunityResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Community'

          attributes :name, :description, :slug, :creator_id

          has_one :creator,
                  class_name: 'Person'
        end
      end
    end
  end
end
