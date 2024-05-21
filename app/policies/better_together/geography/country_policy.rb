# frozen_string_literal: true

module BetterTogether
  module Geography
    class CountryPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        user.present?
      end

      def show?
        user.present?
      end

      def create?
        false
      end

      def new?
        create?
      end

      def update?
        user.present? && !record.protected?
      end

      def edit?
        update?
      end

      def destroy?
        user.present? && !record.protected?
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.order(:identifier)
        end
      end
    end
  end
end
