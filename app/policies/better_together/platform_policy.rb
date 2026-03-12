# frozen_string_literal: true

# app/policies/better_together/platform_policy.rb

module BetterTogether
  class PlatformPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      record.privacy_public? || user.present?
    end

    def create?
      user.present? && can_manage_platform_settings?
    end

    def new?
      create?
    end

    def update?
      user.present? && can_manage_platform_settings?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && can_manage_platform_settings? && !record.protected? && !record.host?
    end

    def available_people?
      PersonPlatformMembershipPolicy.new(user, PersonPlatformMembership.new(joinable: record)).create?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        results = scope.order(:host, :identifier)

        results = results.privacy_public unless can_manage_platform_settings?

        results
      end

      private

      def can_manage_platform_settings?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end

    private

    def can_manage_platform_settings?
      user.permitted_to?('manage_platform_settings', record) || user.permitted_to?('manage_platform')
    end
  end
end
