# frozen_string_literal: true

module BetterTogether
  # Policy for OauthApplication — platform managers can manage all applications.
  # Owners can view/manage their own applications.
  class OauthApplicationPolicy < ApplicationPolicy
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

    private

    def owner?
      return false unless user&.person

      record.respond_to?(:owner_id) && record.owner_id == user.person.id
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
          scope.where(owner: user.person)
        else
          scope.none
        end
      end
    end
  end
end
