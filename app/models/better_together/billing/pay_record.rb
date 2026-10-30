# frozen_string_literal: true

module BetterTogether
  module Billing
    # Abstract base class for Pay's models (see `Pay.model_parent_class` in
    # config/initializers/pay.rb).
    #
    # Pay's records hold payment data, so they deliberately do NOT inherit
    # BetterTogether::ApplicationRecord (that base includes Seedable, which would
    # make payment rows exportable through seeds). Using our own base also means
    # a host app does not need a top-level ApplicationRecord for billing to work.
    class PayRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
