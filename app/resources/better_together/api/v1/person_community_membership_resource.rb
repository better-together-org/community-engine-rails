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

        # Override records to bypass abstract policy scope options issue
        # and handle scoping manually
        def self.records(options = {}) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          context = options[:context]
          user = context[:current_user]
          person = context[:current_person]
          context[:policy_used]&.call

          scope = BetterTogether::PersonCommunityMembership.all
          return scope.none unless user.present?

          # Scope by community_id if nested under communities
          if context[:community_id].present?
            scope = scope.where(joinable_id: context[:community_id], joinable_type: 'BetterTogether::Community')
          end

          # Scope by person_id if nested under people
          if context[:person_id].present?
            return scope.none unless context[:person_id] == person&.id.to_s || person&.permitted_to?('manage_platform')

            scope = scope.where(member_id: context[:person_id])
          end

          return scope.all if person&.permitted_to?('update_community') || person&.permitted_to?('manage_platform')

          scope.where(member_id: person&.id)
        end # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      end
    end
  end
end
