# frozen_string_literal: true

require_dependency 'better_together/api_resource'

module BetterTogether
  module Api
    module V1
      # Serializes the CommunityMembership class
      class CommunityMembershipResource < ::BetterTogether::ApiResource
        model_name '::BetterTogether::CommunityMembership'

        has_one :member,
                class_name: 'BetterTogether::Person'
        has_one :community
        has_one :role
      end
    end
  end
end
