require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the CommunityMembership class
        class CommunityMembershipResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::CommunityMembership'

          has_one :member,
                  class_name: 'Person'
          has_one :community
          has_one :role
        end
      end
    end
  end
end
