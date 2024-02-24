module BetterTogether
  class PersonPolicy < ApplicationPolicy
    def create?
      false
    end

    def me?
      record === user.person
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end
  end
end
