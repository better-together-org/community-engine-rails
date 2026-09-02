# frozen_string_literal: true

module BetterTogether
  module Content
    class PageBlockPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        platform_manager?
      end

      def show?
        platform_manager?
      end

      def create?
        platform_manager?
      end

      def new?
        create?
      end

      def update?
        platform_manager?
      end

      def edit?
        update?
      end

      def destroy?
        platform_manager?
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.none unless platform_manager?

          scope.includes(:page, :block).order(
            BetterTogether::Content::PageBlock.arel_table[:position].asc
          ).all
        end

        private

        def platform_manager?
          return false unless user.present?

          platform = ::Current.platform || ::Current.host_platform
          user.permitted_to?('manage_platform_settings', platform) || user.permitted_to?('manage_platform', platform)
        end
      end

      private

      # PageBlock isn't itself a PlatformRecord (no direct .platform) — resolve via
      # its page, falling back to the current request's platform context when no
      # page is set yet (e.g. index?/create? before a page association exists).
      def target_platform
        record.respond_to?(:page) ? record.page&.platform : nil
      end

      def platform_manager?
        return false unless user.present?

        platform = target_platform || ::Current.platform || ::Current.host_platform
        user.permitted_to?('manage_platform_settings', platform) || user.permitted_to?('manage_platform', platform)
      end
    end
  end
end
