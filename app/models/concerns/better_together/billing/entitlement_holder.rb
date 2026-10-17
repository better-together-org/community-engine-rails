# frozen_string_literal: true

module BetterTogether
  module Billing
    # Open-extension opt-in for "can this record hold something it paid for
    # or was granted" — deliberately distinct from SponsorshipRecipient's
    # accepts_sponsorship? (consent to receive funding from a third party).
    # Conflating the two would incorrectly gate a Person's own paid
    # entitlement on an unrelated sponsorship-consent flag.
    module EntitlementHolder
      extend ActiveSupport::Concern

      included do
        has_many :billing_entitlements,
                 as: :holder,
                 class_name: 'BetterTogether::Billing::Entitlement',
                 dependent: :destroy
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end

      def entitled_to?(entitlement_key)
        BetterTogether::Billing::EntitlementResolver.call(holder: self, entitlement_key:).entitled?
      end
    end
  end
end
