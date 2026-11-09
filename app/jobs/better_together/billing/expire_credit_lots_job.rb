# frozen_string_literal: true

module BetterTogether
  module Billing
    # Lets store credit past its date go, one lot at a time, with an entry for what was lost. A maintenance
    # sweep: the only cross-tenant read, acting on one lot under its own account's lock. Safe to repeat.
    class ExpireCreditLotsJob < ApplicationJob
      def perform
        Credit::ExpireLots.call
      end
    end
  end
end
