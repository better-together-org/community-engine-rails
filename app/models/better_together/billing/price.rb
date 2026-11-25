# frozen_string_literal: true

module BetterTogether
  module Billing
    # What one product costs: an amount in one currency. This is the purchasable a line item points at, taking its name and
    # tax category from its product. A price never changes once made: a different amount is a new price, and the old one is
    # archived (as a payment processor requires), so what an order recorded always matches a price that existed.
    class Price < ApplicationRecord
      include PlatformBound
      include Purchasable
      include MajorAmount
      include Pricing
      include Translatable

      self.table_name = 'better_together_billing_prices'

      # A short name when a product has several prices (for example "Early bird"). Shown beside the amount.
      translates :label, type: :string

      belongs_to :product, class_name: 'BetterTogether::Billing::Product', inverse_of: :prices

      attr_readonly :product_id

      validate :same_platform_as_product
      validate :amount_and_currency_unchanged, on: :update

      before_validation :take_platform_from_product, on: :create

      # What a steward may set when adding a price: the amount (in major units) and currency, and its label in each language.
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [:amount, :currency, :label, *I18n.available_locales.map { |locale| :"label_#{locale}" }]
      end

      scope :active, -> { where(active: true, archived_at: nil) }
      # Prices of what the platform itself sells (a seller belongs to the product).
      scope :sold_by_platform, -> { where(product_id: Product.sold_by_platform.select(:id)) }

      # Takes the price out of sale. History is kept.
      def archive!
        update!(active: false, archived_at: Time.current)
      end

      def archived? = archived_at.present?

      # Purchasable: the product's name, with the price's label when it has one.
      def purchasable_description = [product.name, label.presence].compact.join(' - ')

      def purchasable_description_in(locale)
        name = product.name(locale:, fallback: false)
        return if name.blank?

        [name, label(locale:, fallback: false).presence].compact.join(' - ')
      end

      def purchasable_tax_category = product.tax_category
      def purchasable? = active? && !archived? && product.active?

      # What the order engine asks: a standard product is given through its own order; a subclass answers for itself.
      def fulfilled_by_order? = product.fulfilled_by_order?

      def held_by?(person) = product.respond_to?(:held_by?) && product.held_by?(person)

      # What checkout reads, so a price is bought like a plan: one-off, never an extra on a plan, paid by any way the platform
      # settles itself (an online processor for products arrives with the processor contract).
      def name = purchasable_description
      def billing_interval = 'one_time'
      def recurring? = false
      def add_on? = false
      def payment_methods = Billing.processor_names.map(&:to_s).select { |method| Billing.local_method?(method) }

      private

      def take_platform_from_product
        self.platform_id ||= product&.platform_id
      end

      def amount_and_currency_unchanged
        errors.add(:base, :price_is_immutable) if amount_cents_changed? || currency_changed?
      end

      def same_platform_as_product
        errors.add(:product, :platform_owner_mismatch) if product && platform_id != product.platform_id
      end
    end
  end
end
