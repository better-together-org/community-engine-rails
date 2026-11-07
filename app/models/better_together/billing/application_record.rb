# frozen_string_literal: true

module BetterTogether
  module Billing
    # Abstract base for Community Engine's own billing models (events, plans, ...).
    #
    # Inside `module Billing`, `ApplicationRecord` resolves to this class rather than
    # BetterTogether::ApplicationRecord, so billing models pick it up by writing
    # `class Plan < ApplicationRecord` like every other model.
    #
    # It deliberately does NOT include Seedable: that concern adds
    # `export_as_seed`, which would let a billing record, with its decrypted
    # payment data, be written into a seed. It also skips BetterTogetherId; the
    # tables use the database's own uuid default.
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.implicit_order_column = :created_at
    end
  end
end
