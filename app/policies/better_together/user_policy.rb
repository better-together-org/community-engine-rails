
module BetterTogether
  class UserPolicy < ApplicationPolicy
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