# frozen_string_literal: true

module BetterTogether
  module Billing
    module Processors
      # Store credit: a balance the buyer holds with the platform, spent whole on a platform-sold
      # order (see Billing::Credit). Credit is platform money, so it works only for what the
      # platform itself sells, never for a seller's own plans.
      class StoreCredit < InternalProcessorAdapter
        def processor_name = :store_credit
      end
    end
  end
end
