# frozen_string_literal: true

module BetterTogether
  module Billing
    # A plan is bought through its recurring price, so what a plan is "sold at" (amount, currency, interval and how many intervals,
    # and the processor's id for the price) lives on that Price row, not on the plan. This lets a plan be read and written as one
    # thing, as a steward does in the form: the attributes below are read from its current recurring price and, when saved,
    # written to it. A price never changes once made, so a change of terms is a new price and the old one is archived.
    #
    # Adding a second price to a plan (an annual one beside a monthly one) is done through `prices` and is not read here.
    module PlanPrice
      extend ActiveSupport::Concern

      TERMS = %w[amount_cents currency billing_interval interval_count].freeze

      included do
        attribute :amount_cents, :integer, default: 0
        attribute :currency, :string
        attribute :billing_interval, :string, default: 'month'
        attribute :interval_count, :integer, default: 1
        attribute :processor_price_id, :string

        after_initialize :read_price, if: :persisted?
        after_save :write_price
      end

      # The recurring price a new subscription starts on: the newest one in sale.
      def current_price = prices.active.where(kind: 'recurring').order(created_at: :desc).first

      def reload(*)
        super.tap { read_price if persisted? }
      end

      # Stores what the processor answered, then shows it.
      def apply_sync_result!(result)
        super.tap { read_price }
      end

      private

      def read_price
        price = current_price
        return unless price

        assign_price_attributes(price)
        clear_attribute_changes(%w[amount_cents currency billing_interval interval_count processor_price_id])
      end

      def assign_price_attributes(price)
        self.amount_cents = price.amount_cents
        self.currency = price.currency
        self.billing_interval = price.interval
        self.interval_count = price.interval_count
        self.processor_price_id = price.processor_price_id
      end

      def write_price
        price = current_price
        if price.nil? || terms_changed_from?(price)
          price&.archive!
          create_recurring_price
        elsif processor_price_id.to_s != price.processor_price_id.to_s
          price.update_columns(processor_price_id: processor_price_id.presence) # rubocop:disable Rails/SkipsModelValidations
        end
        prices.reset
        clear_attribute_changes(%w[amount_cents currency billing_interval interval_count processor_price_id])
      end

      def terms_changed_from?(price)
        price.amount_cents != amount_cents || price.currency != currency || price.interval != billing_interval ||
          price.interval_count != interval_count
      end

      def create_recurring_price
        prices.create!(skip_product_sync: true, platform_id:, kind: 'recurring', interval: billing_interval, interval_count:,
                       amount_cents:, currency:,
                       processor_price_id: processor_price_id.presence)
      end
    end
  end
end
