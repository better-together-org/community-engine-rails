# frozen_string_literal: true

module BetterTogether
  module Content
    class BlockPolicy < ApplicationPolicy
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

      class Scope < Scope
        def resolve
          scope.includes(:pages).order('created_at DESC').all
        end
      end
    end
  end
end
