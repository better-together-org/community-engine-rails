require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the CommunityMembership class
        class CommunityMembershipResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::CommunityMembership'

          has_one :member,
                  always_include_linkage_data: true
          has_one :community,
                  always_include_linkage_data: true
          has_one :role

          filters :member, :community, :role
        end
      end
    end
  end
end
