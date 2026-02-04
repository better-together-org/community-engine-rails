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

        # Override records to scope by parent resource
        def self.records(options = {})
          context = options[:context]
          records = super

          # Scope by community_id if nested under communities
          if context && context[:community_id].present?
            records = records.where(joinable_id: context[:community_id], joinable_type: 'BetterTogether::Community')
          end

          # Scope by person_id if nested under people
          if context && context[:person_id].present?
            records = records.where(member_id: context[:person_id])
          end

          records
        end
      end
    end
  end
end
