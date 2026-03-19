# frozen_string_literal: true

module BetterTogether
  module Content
    class PageBlockPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
      def index?
        user.present? and user.permitted_to?('manage_platform')
      end

      def show?
        user.present? and user.permitted_to?('manage_platform')
      end

      def create?
        user.present? and user.permitted_to?('manage_platform')
      end

      def new?
        create?
      end

      def update?
        user.present? and user.permitted_to?('manage_platform')
      end

      def edit?
        update?
      end

      def destroy?
        user.present? and user.permitted_to?('manage_platform')
      end

      class Scope < Scope # rubocop:todo Style/Documentation
        def resolve
          scope.includes(:page, :block).order(
            BetterTogether::Content::PageBlock.arel_table[:position].asc
          ).all
        end
      end
    end
  end
end
