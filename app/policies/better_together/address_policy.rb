# frozen_string_literal: true

module BetterTogether
  class AddressPolicy < ContactDetailPolicy
    # Inherits from ContactDetailPolicy

    class Scope < ContactDetailPolicy::Scope
    end
  end
end
