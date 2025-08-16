# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Request
    class RequestPolicy < ApplicationPolicy
      def index? = user.present?
      def show?  = user.present?
      def create? = user.present?
      alias new? create?

      def update?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end
      alias edit? update?

      def destroy?
        return false unless user.present?

        permitted_to?('manage_platform') || record.creator_id == agent&.id
      end

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.none unless user.present?

          scope.all
        end
      end
    end
  end
end
