# frozen_string_literal: true

module BetterTogether
  module BreakGlass
    # Raised when the requester lacks the sealed disclosure permission on the record's platform.
    class NotAuthorized < StandardError; end
  end
end
