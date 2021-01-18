
module BetterTogether
  class PersonPolicy < ApplicationPolicy
    def create?
      false
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end