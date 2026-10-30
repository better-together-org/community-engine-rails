# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model as something a billing event can be about (an order, a Joatu
    # agreement, a ticket, a platform). Including it is the opt-in; Billing::Event only
    # accepts subject types registered here, so a type name never has to be resolved
    # from a string. Billable is the same idea for the owners of billing records.
    module Subjectable
      extend ActiveSupport::Concern

      included do
        Subjectable.model_names << name if name.present?
      end

      # Class names, not constants, so code reloading never holds stale classes.
      def self.model_names
        @model_names ||= Concurrent::Set.new
      end
    end
  end
end
