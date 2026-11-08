# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model (Community, Person, or a host model) as able to own billing
    # records. Including it is the opt-in; Billing::Event only accepts owner types
    # registered here. Later chunks add the Pay wiring to this concern.
    module Billable
      extend ActiveSupport::Concern

      included do
        Billable.model_names << name if name.present?
      end

      # Class names, not constants, so code reloading never holds stale classes.
      def self.model_names
        @model_names ||= Concurrent::Set.new
      end
    end
  end
end
