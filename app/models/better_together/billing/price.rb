# frozen_string_literal: true

module BetterTogether
  module Billing
    # What one product costs: an amount in one currency, once or recurring. This is the purchasable a line item points at, taking its name and
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

      KINDS = %w[one_time recurring].freeze
      INTERVALS = %w[month year].freeze

      attr_readonly :product_id
      # Set when the product is pushing itself anyway (a plan saving its own price), so it is not pushed twice.
      attr_accessor :skip_product_sync

      validates :kind, inclusion: { in: KINDS }
      validates :interval, inclusion: { in: INTERVALS }, if: :recurring?
      validates :interval, absence: true, unless: :recurring?
      validates :interval_count, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 36 }
      validates :lookup_key, uniqueness: { scope: :platform_id }, allow_nil: true
      validate :same_platform_as_product
      validate :terms_unchanged, on: :update

      before_validation :take_platform_from_product, on: :create
      # A price added to a product the processor holds is pushed with it.
      after_commit(on: :create) { product.queue_processor_sync unless skip_product_sync }

      # What a steward may set when adding a price: the amount (in major units) and currency, and its label in each language.
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [:amount, :currency, :label, *I18n.available_locales.map { |locale| :"label_#{locale}" }]
      end

      scope :active, -> { where(active: true, archived_at: nil) }
      # Prices of what the platform itself sells (a seller belongs to the product).
      scope :sold_by_platform, -> { where(product_id: Product.sold_by_platform.select(:id)) }

      # Prices of products sold only with something else, newest first within a product.
      scope :extras, -> { where(product_id: Product.extras.select(:id)) }

      # Takes the price out of sale. History is kept.
      def archive!
        update!(active: false, archived_at: Time.current)
      end

      def archived? = archived_at.present?

      # Purchasable: the product's name, with the price's label when it has one.
      delegate :seller_id, :seller_type, to: :product

      def purchasable_description = [product.name, label.presence].compact.join(' - ')

      def purchasable_description_in(locale)
        name = product.name(locale:, fallback: false)
        return if name.blank?

        [name, label(locale:, fallback: false).presence].compact.join(' - ')
      end

      def purchasable_tax_category = product.tax_category
      def purchasable? = active? && !archived? && product.active?

      # What the order engine asks. A recurring price starts a subscription and is read as a plan order, and what it includes is given
      # through that subscription, never as a one-off entitlement of the order. A one-time price on a standard product is given
      # through its own order; a subclass answers for itself.
      def renews? = recurring?
      def plan_line? = recurring?
      def fulfilled_by_order? = !recurring? && product.fulfilled_by_order?

      def held_by?(person) = product.held_by?(person)

      # An extra when its product is sold only with something else; on a plan order it rides along like an add-on did.
      def extra? = product.extra?

      # What checkout reads, so a price is bought like a plan: one-off, never an extra on a plan, paid by any way the platform
      # settles itself, or by an online processor that takes checkout lines (contract version 2), where it is sent inline.
      def name = purchasable_description

      # What checkout shows beneath a price: the product's summary, else its description.
      def display_participant_summary = product.summary.presence || product.description
      def billing_interval = recurring? ? interval : 'one_time'
      def recurring? = kind == 'recurring'

      def payment_methods
        return [] if free?

        Billing.processor_names.map(&:to_s).select { |method| Billing.local_method?(method) || online_here?(method) }
      end

      private

      # An online processor is offered for a price only when its product names that processor (a steward's choice) and the adapter
      # takes checkout lines. A price the processor does not hold yet is sent inline.
      def online_here?(method) = product.processor.to_s == method && Billing.online_checkout_method?(method)

      def take_platform_from_product
        self.platform_id ||= product&.platform_id
      end

      def terms_unchanged
        return unless amount_cents_changed? || currency_changed? || kind_changed? || interval_changed? || interval_count_changed?

        errors.add(:base, :price_is_immutable)
      end

      def same_platform_as_product
        errors.add(:product, :platform_owner_mismatch) if product && platform_id != product.platform_id
      end
    end
  end
end
