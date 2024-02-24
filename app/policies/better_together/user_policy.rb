# frozen_string_literal: true

module BetterTogether
  class UserPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      false
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end
  end
end
