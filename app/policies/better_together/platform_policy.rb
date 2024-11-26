# frozen_string_literal: true

# app/policies/better_together/platform_policy.rb

module BetterTogether
  class PlatformPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      record.privacy_public? || user.present?
    end

    def create?
      user.present?
    end

    def new?
      create?
    end

    def update?
      user.present? && user.permitted_to?('manage_platform')
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && !record.protected? && !record.host?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(:host, :identifier)
      end
    end
  end
end
