# frozen_string_literal: true

module BetterTogether
  module Geography
    class MapPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        user.present? && permitted_to?('manage_platform')
      end

      def show?
        user.present? && (record.creator == agent || permitted_to?(:manage_platform))
      end

      def create?
        user.present? && permitted_to?('manage_platform')
      end

      def update?
        user.present? && (record.creator == agent || permitted_to?(:manage_platform))
      end

      def destroy?
        user.present? && !record.protected? && (record.creator == agent || permitted_to?(:manage_platform))
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          super
        end
      end
    end
  end
end
