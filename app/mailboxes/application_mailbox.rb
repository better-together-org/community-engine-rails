# frozen_string_literal: true

unless defined?(ApplicationMailbox)
  # Root Action Mailbox router used by the engine for inbound email processing.
  class ::ApplicationMailbox < ActionMailbox::Base
    routing all: 'BetterTogether::Router'
  end
end
