# frozen_string_literal: true

module BetterTogether
  module Billing
    # Marks a model (Community, Person, Platform, or a host model) as able to own billing
    # records. Including it is the opt-in; Billing::Event only accepts owner types
    # registered here.
    #
    # `billing_bound_platform_id` says which single platform an owner's billing records must
    # live on. A community is bound to its platform and a platform to itself. A person is
    # bound to none: one person can be a customer of several platforms (see PayCustomerOwner).
    module Billable
      extend ActiveSupport::Concern

      included do
        Billable.model_names << name if name.present?
      end

      def billing_bound_platform_id
        return id if is_a?(BetterTogether::Platform)

        try(:platform_id)
      end

      # Class names, not constants, so code reloading never holds stale classes.
      def self.model_names
        @model_names ||= Concurrent::Set.new
      end
    end
  end
end
