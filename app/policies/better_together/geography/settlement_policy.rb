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

      # The weather tab is public like the settlement page itself.
      def weather?
        show?
      end

      def create?
        false
      end

      def new?
        create?
      end

      def update?
        user.present? && host_platform_manager?
      end

      def edit?
        update?
      end

      def destroy?
        user.present? && !record.protected? && host_platform_manager?
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.order(:identifier)
        end
      end
    end
  end
end
