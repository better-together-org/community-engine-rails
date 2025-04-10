# frozen_string_literal: true

module BetterTogether
  module Geography
    class MapPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        user.present?
      end

      def show?
        user.present?
      end

      def create?
        user.present?
      end

      def update?
        user.present? && !record.protected? && (record.creator == agent || permitted_to(:manage_platform))
      end

      def destroy?
        user.present? && !record.protected? && (record.creator == agent || permitted_to(:manage_platform))
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.order(created_at: :desc)
        end
      end
    end
  end
end
