# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Pay knows its processors by name: it gives its customers, subscriptions and charges a
      # predicate and a scope for each (`stripe?`, `Pay::Subscription.stripe`), and none for ours.
      # This adds `local?` and `.local` for the processor Community Engine settles itself
      # (Pay::Local), the same way.
      #
      # Included into Pay::Customer, Pay::Subscription and Pay::Charge
      # (config/initializers/billing_pay_extensions.rb).
      module LocalProcessor
        extend ActiveSupport::Concern

        PROCESSOR = 'local'

        included do
          if name == 'Pay::Customer'
            scope :local, -> { where(processor: PROCESSOR) }
          else
            scope :local, -> { joins(:customer).where(pay_customers: { processor: PROCESSOR }) }
          end
        end

        def local?
          (respond_to?(:customer) ? customer.processor : processor) == PROCESSOR
        end
      end
    end
  end
end
