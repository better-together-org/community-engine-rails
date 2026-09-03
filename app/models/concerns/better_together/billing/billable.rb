# frozen_string_literal: true

module BetterTogether
  module Billing
    # Shared Pay-gem wiring for models that can be billed directly (Community, Person).
    module Billable
      extend ActiveSupport::Concern

      included do
        pay_customer default_payment_processor: :stripe, stripe_attributes: :stripe_customer_attributes
        pay_merchant

        has_many :owned_billing_events,
                 as: :billable_owner,
                 class_name: 'BetterTogether::Billing::Event',
                 dependent: :nullify
        has_many :merchant_accounts,
                 as: :owner,
                 class_name: 'BetterTogether::Billing::MerchantAccount',
                 dependent: :destroy
      end

      def self.included_in_models
        included_module = self
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select { |model| model.include?(included_module) }
      end

      def pay_customer_name
        name
      end

      def pay_should_sync_customer?
        super || saved_change_to_name?
      end

      def stripe_customer_attributes(pay_customer)
        { metadata: base_stripe_customer_metadata(pay_customer).merge(billing_owner_metadata) }
      end

      private

      def base_stripe_customer_metadata(pay_customer)
        {
          bt_billable_owner_type: self.class.name,
          bt_billable_owner_id: id,
          bt_beneficiary_type: self.class.name,
          bt_beneficiary_id: id,
          pay_customer_id: pay_customer.id
        }
      end

      # Overridden by each including model to add its own identifying metadata keys.
      def billing_owner_metadata
        {}
      end
    end
  end
end
