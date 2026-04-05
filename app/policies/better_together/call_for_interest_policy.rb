# frozen_string_literal: true

module BetterTogether
  # Policy for calls for interest
  class CallForInterestPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      public_or_member_scoped_community?(record) || platform_cfi_manager?
    end

    def create?
      platform_cfi_manager?
    end

    def update?
      platform_cfi_manager?
    end

    def destroy?
      platform_cfi_manager?
    end

    class Scope < ApplicationPolicy::Scope
    end

    private

    def platform_cfi_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
