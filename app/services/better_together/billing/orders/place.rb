# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Places an order: a draft with its line items, the purchasables held, then waiting for payment.
      #
      # Everything happens in one transaction, so a refusal part-way leaves nothing behind (and
      # nothing held). It refuses what could not be sold: no line items, a purchasable that is not
      # for sale or belongs to another platform or seller, or line items in different currencies.
      #
      #   Orders::Place.call(platform:, buyer:, purpose: 'one_time', line_items: [{ purchasable: plan }])
      class Place
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        # `line_items` are hashes with `purchasable:` and an optional `quantity:`.
        def initialize(platform:, buyer:, purpose:, line_items:, seller: nil, on_behalf_of: nil, subject: nil, hold_hours: nil) # rubocop:disable Metrics/ParameterLists
          @platform = platform
          @buyer = buyer
          @purpose = purpose.to_s
          @line_items = Array(line_items)
          @seller = seller
          @on_behalf_of = on_behalf_of
          @subject = subject
          @hold_hours = hold_hours
        end

        def call
          check_lines!
          Order.transaction { open_for_payment(build_order.tap(&:save!)) }
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :platform, :buyer, :purpose, :line_items, :seller, :on_behalf_of, :subject

        def open_for_payment(order)
          reserve(order)
          order.update!(status: 'awaiting_payment', placed_at: Time.current, expires_at: hold_hours.hours.from_now)
          Settle.call(order) if order.total_cents.zero?
          order
        end

        def hold_hours = @hold_hours || Order::DEFAULT_HOLD_HOURS

        def check_lines!
          raise Refused, 'an order needs at least one line' if line_items.empty?

          purchasables.each { |purchasable| check_purchasable!(purchasable) }
          raise Refused, 'all line items must be in the same currency' if purchasables.map(&:purchasable_currency).uniq.size > 1
        end

        def purchasables = @purchasables ||= line_items.map { |line_item| line_item.fetch(:purchasable) }

        def check_purchasable!(purchasable)
          raise Refused, 'that cannot be bought' unless Purchasable.model_names.include?(purchasable.class.name)
          raise Refused, 'that is not for sale' unless purchasable.purchasable?
          raise Refused, 'that belongs to another platform' if purchasable.try(:platform_id) != platform.id
          raise Refused, 'that is sold by someone else' unless same_seller?(purchasable)
        end

        def same_seller?(purchasable)
          return seller.nil? if purchasable.try(:seller_id).blank?

          seller.present? && purchasable.seller_type == seller.class.name && purchasable.seller_id == seller.id
        end

        def build_order
          order = platform.billing_orders.build(buyer:, purpose:, seller:, on_behalf_of:, subject:,
                                                currency: purchasables.first.purchasable_currency, status: 'draft')
          line_items.each_with_index { |line_item, index| order.line_items.build(line_item_attributes(line_item, index)) }
          order
        end

        def line_item_attributes(line_item, index)
          purchasable = line_item.fetch(:purchasable)
          { platform_id: platform.id, position: index, purchasable:, quantity: line_item.fetch(:quantity, 1),
            description: purchasable.purchasable_description, unit_amount_cents: purchasable.purchasable_amount_cents,
            currency: purchasable.purchasable_currency }
        end

        # Holds each purchasable for the order. If one refuses, the transaction rolls back and
        # whatever was held before it is released with it.
        def reserve(order)
          order.line_items.each { |line_item| line_item.purchasable.reserve!(quantity: line_item.quantity) }
        rescue StandardError => e
          raise Refused, e.message
        end
      end
    end
  end
end
