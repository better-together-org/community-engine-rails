# frozen_string_literal: true

unless defined?(ApplicationMailbox)
  # Backward-compatible root mailbox for apps that have not yet defined their
  # own ApplicationMailbox subclass.
  class ::ApplicationMailbox < BetterTogether::ApplicationMailbox
  end
end
