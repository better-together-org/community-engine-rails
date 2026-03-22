# frozen_string_literal: true

module BetterTogether
  module Geography
    class MapPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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

      class Scope < Scope
      end

      private

      def platform_map_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end
  end
end
