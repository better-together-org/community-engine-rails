# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Offer
    class OfferPolicy < ApplicationPolicy
      def index?
        permitted_to?('manage_platform')
      end

      def show?
        permitted_to?('manage_platform')
      end

      def create?
        permitted_to?('manage_platform')
      end
      alias new? create?

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          return scope.all if permitted_to?('manage_platform')

          scope.none
        end
      end
    end
  end
end
