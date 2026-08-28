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

    def agreement_manager?(target = record)
      platform = (target.respond_to?(:platform) ? target.platform : nil) || current_platform
      permitted_to?(:manage_platform_settings, platform) || permitted_to?(:manage_platform, platform)
    end
  end
end
