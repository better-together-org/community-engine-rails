# frozen_string_literal: true

module BetterTogether
  module Geography
    class SettlementPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        true
      end

      def show?
        true
      end

      def create?
        false
      end

      def new?
        create?
      end

      def update?
        user.present? && permitted_to?('manage_platform')
      end

      def edit?
        update?
      end

      def destroy?
        user.present? && !record.protected? && permitted_to?('manage_platform')
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.order(:identifier)
        end
      end
    end
  end
end
