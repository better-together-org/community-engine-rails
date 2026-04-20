# frozen_string_literal: true

module BetterTogether
  # Routes inbound mail into CE community, request, and agent targets.
  class RouterMailbox < ActionMailbox::Base
    def process
      BetterTogether::InboundEmailRoutingService.new(inbound_email).route!
    end
  end
end
