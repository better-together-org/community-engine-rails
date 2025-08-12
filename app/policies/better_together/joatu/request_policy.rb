# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::Request
    class RequestPolicy < ApplicationPolicy
      def index?
        true
      end

      def show?
        true
      end

      def create?
        true
      end
      alias new? create?

      class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
        def resolve
          scope.all
        end
      end
    end
  end
end
