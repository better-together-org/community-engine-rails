module BetterTogether
  class ContactDetailPolicy < ApplicationPolicy
    def create?
      true # Adjust as per your authorization logic
    end

    def destroy?
      true # Adjust as per your authorization logic
    end

    class Scope < ApplicationPolicy::Scope
      
    end
  end
end