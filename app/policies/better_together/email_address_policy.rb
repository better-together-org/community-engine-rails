# frozen_string_literal: true

module BetterTogether
  class EmailAddressPolicy < ContactDetailPolicy
    # Inherits from ContactDetailPolicy

    class Scope < ContactDetailPolicy::Scope
    end
  end
end
