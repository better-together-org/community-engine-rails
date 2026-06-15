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

    def accept?
      show?
    end

    def update?
      agreement_manager?
    end

    def create?
      agreement_manager?
    end

    # Agreements scoped to the current platform context.
    class Scope < ApplicationPolicy::Scope
      def resolve
        platform = Current.platform || BetterTogether::Platform.find_by(host: true)
        base = platform ? scope.where(platform_id: platform.id) : scope.none
        base.order(created_at: :desc)
      end
    end

    private

    def agreement_manager?
      permitted_to?(:manage_platform_settings) || permitted_to?(:manage_platform)
    end
  end
end
