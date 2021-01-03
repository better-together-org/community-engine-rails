
module BetterTogether
  class RolePolicy < ApplicationPolicy
    def create?
      true
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end