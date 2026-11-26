# frozen_string_literal: true

module BetterTogether
  module Billing
    module PurchaseRequirements
      # When an order that gave a prerequisite is refunded or cancelled, takes back what the buyer's other paid lines gave if
      # their rule says `revoke`. A rule that says `keep` (the default) leaves the dependent alone. The buyer keeps a dependent
      # when they still hold the prerequisite another way. Safe to run again: a purchasable's `revoke_line` must be idempotent.
      class RevokeDependents
        HELD_ORDERS = %w[paid partially_refunded].freeze

        def self.call(...) = new(...).call

        def initialize(order:)
          @order = order
        end

        # Returns the lines it asked a purchasable to revoke.
        def call
          return [] if order.buyer.blank?

          lines = ending_rules.uniq.flat_map { |rule| dependent_lines(rule).to_a }
          lines.each { |line_item| line_item.purchasable.revoke_line(line_item) }
        end

        private

        attr_reader :order

        def ending_rules
          ended_prerequisites.flat_map { |prerequisite| rules_ending_with(prerequisite).to_a } + kind_rules_ending
        end

        # Prerequisites this order gave that the buyer no longer holds some other way.
        def ended_prerequisites
          order.line_items.flat_map { |line| prerequisites_of(line.purchasable) }.uniq
               .reject { |prerequisite| prerequisite.held_by?(order.buyer) }
        end

        # A price stands for its product too, since a rule names the product.
        def prerequisites_of(purchasable) = purchasable.is_a?(Price) ? [purchasable, purchasable.product] : [purchasable]

        def rules_ending_with(prerequisite)
          PurchaseRequirement.where(prerequisite:, on_prerequisite_end: 'revoke', platform_id: order.platform_id)
        end

        # A rule on a kind of prerequisite ("any plan") ends when this order gave one of that kind and the buyer holds none now.
        def kind_rules_ending
          kinds = PurchaseRequirement::KINDS.select { |_kind, class_name| gave_kind?(class_name) && !holds_kind?(class_name) }.keys
          return [] if kinds.empty?

          PurchaseRequirement.where(prerequisite_kind: kinds, on_prerequisite_end: 'revoke', platform_id: order.platform_id).to_a
        end

        def gave_kind?(class_name)
          order.line_items.any? do |line_item|
            line_item.purchasable.instance_of?(class_name.constantize) && !line_item.purchasable.extra?
          end
        end

        # Only plans are a kind today, so holding the kind is holding any plan.
        def holds_kind?(_class_name)
          Plans::Holdings.call(platform: order.platform, person: order.buyer).any?
        end

        def dependent_lines(rule)
          LineItem.joins(:order)
                  .where(purchasable_type: line_type(rule), purchasable_id: line_ids(rule))
                  .where(better_together_billing_orders: { platform_id: order.platform_id, buyer_id: order.buyer_id,
                                                           status: HELD_ORDERS })
                  .where.not(order_id: order.id)
        end

        # A rule on a product reaches the lines of any of its prices.
        def line_type(rule) = rule.dependent.is_a?(Product) ? Price.name : rule.dependent_type
        def line_ids(rule) = rule.dependent.is_a?(Product) ? rule.dependent.prices.select(:id) : rule.dependent_id
      end
    end
  end
end
