# frozen_string_literal: true

module BetterTogether
  class PersonPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def create?
      false
    end

    def me?
      record === user.person
    end

    class Scope < Scope # rubocop:todo Style/Documentation
      def resolve
        scope.all
      end
    end
  end
end
