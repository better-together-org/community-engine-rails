# frozen_string_literal: true

module BetterTogether
  # Policy for WebhookEndpoint — only platform managers can manage webhooks.
  # Owners can view/manage their own endpoints.
  class WebhookEndpointPolicy < ApplicationPolicy
    def index?
      platform_manager?
    end

    def show?
      platform_manager? || owner?
    end

    def create?
      platform_manager?
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

    def platform_manager?
      user&.person&.permitted_to?('manage_platform')
    end

    # Scope: platform managers see all, others see their own
    class Scope < ApplicationPolicy::Scope
      def resolve
        if user&.person&.permitted_to?('manage_platform')
          scope.all
        elsif user&.person
          scope.where(person: user.person)
        else
          scope.none
        end
      end
    end
  end
end
