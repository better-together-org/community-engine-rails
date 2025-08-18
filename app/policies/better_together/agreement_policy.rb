# frozen_string_literal: true

module BetterTogether
  # Access control for agreements
  class AgreementPolicy < ApplicationPolicy
    def index?
      permitted_to? :manage_platform
    end

    def show?
      true
    end

    def update?
      permitted_to? :manage_platform
    end

    def create?
      permitted_to? :manage_platform
    end

    # Filtering and sorting for agreements according to permissions and context
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(created_at: :desc)
      end
    end
  end
end
