# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model as something a purchase agreement can be attached to (a seller, a plan,
    # later an event or a ticket type), so a seller or a product can ask buyers for terms of its
    # own. Only registered types are accepted, so a type name is never resolved from a string.
    module AgreementTarget
      extend ActiveSupport::Concern

      included do
        AgreementTarget.model_names << name if name.present?
      end

      # Class names, not constants, so code reloading never holds stale classes.
      def self.model_names
        @model_names ||= Concurrent::Set.new
      end
    end
  end
end
