# frozen_string_literal: true

module BetterTogether
  module Geography
    class MapPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
      def index?
        user.present? && platform_map_manager?
      end

      def show?
        user.present? && (record.creator == agent || platform_map_manager?)
      end

      def create?
        user.present? && platform_map_manager?
      end

      def update?
        user.present? && (record.creator == agent || platform_map_manager?)
      end

      def destroy?
        user.present? && !record.protected? && (record.creator == agent || platform_map_manager?)
      end

      class Scope < PlatformRecordPolicy::Scope
      end

      private

      def platform_map_manager?(target = record.try(:platform) || current_platform)
        permitted_to?('manage_platform_settings', target) || permitted_to?('manage_platform', target)
      end
    end
  end
end
