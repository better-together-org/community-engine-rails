# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    class BuildingPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
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
        user.present? && !record.protected? && record.creator == agent
      end

      def destroy?
        user.present? && !record.protected? && record.creator == agent
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.order(created_at: :desc)
        end
      end
    end
  end
end
