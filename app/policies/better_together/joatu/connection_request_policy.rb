# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Access control for Joatu::ConnectionRequest — inherits all RequestPolicy logic.
    # ConnectionRequest is a specialised Request subtype; all permission checks are
    # already handled by the parent via the #connection_request? guard.
    class ConnectionRequestPolicy < RequestPolicy
    end
  end
end
