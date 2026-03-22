# frozen_string_literal: true

module BetterTogether
  # Access control for agreements
  class AgreementPolicy < ApplicationPolicy
    def index?
      agreement_manager?
    end

    def show?
      true
    end

    def update?
      agreement_manager?
    end

    def create?
      agreement_manager?
    end

    # Filtering and sorting for agreements according to permissions and context
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.order(created_at: :desc)
      end
    end

    private

    def agreement_manager?
      permitted_to?(:manage_platform_settings) || permitted_to?(:manage_platform)
    end
  end
end
