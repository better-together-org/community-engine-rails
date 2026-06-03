# frozen_string_literal: true

module BetterTogether
  # Policy for WebhookEndpoint — explicit API managers can manage platform webhooks.
  # Owners can view/manage their own endpoints.
  class WebhookEndpointPolicy < ApplicationPolicy
    def index?
      platform_manager?
    end

    def show?
      platform_manager? || owner?
    end

    def create?
      platform_manager? || community_admin?
    end

    def update?
      platform_manager? || owner?
    end

    def destroy?
      platform_manager? || owner?
    end

    # Custom action: send a test ping to the endpoint
    def test?
      platform_manager? || owner?
    end

    private

    def owner?
      return false unless user&.person

      record.person_id == user.person.id
    end

    def community_admin?
      return false unless user&.person && record.respond_to?(:community) && record.community.present?

      user.person.permitted_to?('update_community', record.community)
    end

    def platform_manager?
      can_manage_webhook_endpoints?
    end

    # Scope: platform managers see all, others see their own + community endpoints they admin
    class Scope < ApplicationPolicy::Scope
      # rubocop:disable Metrics/AbcSize
      def resolve
        if user&.person&.permitted_to?('manage_platform_api')
          scope.all
        elsif user&.person
          scope.where(person: user.person)
               .or(scope.where(community_id: managed_community_ids))
        else
          scope.none
        end
      end
      # rubocop:enable Metrics/AbcSize

      private

      def managed_community_ids
        BetterTogether::Community
          .select(:id)
          .joins(:person_community_memberships)
          .where(better_together_person_community_memberships: { member_id: user.person.id })
          .filter_map do |community|
            community.id if user.person.permitted_to?('update_community', community)
          end
      end
    end
  end
end
