# frozen_string_literal: true

module BetterTogether
  module Billing
    # Abstract base class for Pay's models (see `Pay.model_parent_class` in
    # config/initializers/pay.rb).
    #
    # Pay's records hold payment data, so they inherit the billing base (no
    # Seedable, so payment rows cannot be exported through seeds) rather than
    # BetterTogether::ApplicationRecord. Using our own base also means a host app
    # does not need a top-level ApplicationRecord for billing to work.
    class PayRecord < ApplicationRecord
      self.abstract_class = true
    end
  end
end
