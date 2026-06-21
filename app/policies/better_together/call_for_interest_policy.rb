# frozen_string_literal: true

module BetterTogether
  # Policy for calls for interest
  class CallForInterestPolicy < PlatformRecordPolicy
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

    class Scope < PlatformRecordPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        base = platform_scoped
        table = scope.arel_table

        query = table[:privacy].eq('public')

        if agent.present?
          community_query = scoped_community_privacy_query(table)
          query = query.or(community_query) if community_query
          query = query.or(table[:privacy].eq('private')) if permitted_to?('manage_platform')
        end

        base.where(query).order(created_at: :desc)
      end
    end

    private

    def platform_cfi_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end
  end
end
