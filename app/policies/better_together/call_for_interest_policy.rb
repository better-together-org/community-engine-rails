# frozen_string_literal: true

module BetterTogether
  # Policy for calls for interest
  class CallForInterestPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      record.privacy_public? || permitted_to?('manage_platform')
    end

    def create?
      permitted_to?('manage_platform')
    end

    def update?
      permitted_to?('manage_platform')
    end

    def destroy?
      permitted_to?('manage_platform')
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
