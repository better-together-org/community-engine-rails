# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the PersonCommunityMembership class
      class PersonCommunityMembershipResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::PersonCommunityMembership'

        # Attributes
        attribute :status

        # Relationships
        has_one :member, class_name: 'Person'
        has_one :joinable, class_name: 'Community', foreign_key: :joinable_id
        has_one :role

        # Filters
        filter :status
        filter :member_id
        filter :joinable_id
      end
    end
  end
end
