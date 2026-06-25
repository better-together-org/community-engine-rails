# frozen_string_literal: true

module BetterTogether
  # Access control for agreements
  class AgreementPolicy < PlatformRecordPolicy
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

    class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        platform_scoped.order(created_at: :desc)
      end
    end

    private

    def agreement_manager?
      permitted_to?(:manage_platform_settings) || permitted_to?(:manage_platform)
    end
  end
end
