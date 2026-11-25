# frozen_string_literal: true

module BetterTogether
  module Billing
    # A one-off item a platform (or one of its communities or people) sells: a storage top-up, a one-time add-on, later
    # tickets and other goods. The product is the thing sold, with its name, listing and tax category; what a buyer pays is
    # a Price, and the Price is what a line item points at. See docs/billing/purchasable_split_plan.md.
    #
    # `type` names a subclass from the allow-list in `SUBTYPES` and is never set from a parameter. The base class is the
    # standard product, fulfilled through its grants; a subclass overrides the hooks (`fulfilled_by_order?`, `held_by?`,
    # `revoke_line`) where it differs.
    #
    # `lifetime` says what a purchase gives for how long: `until_used` (no end date) or `fixed_term` (ends `term_length`
    # `term_unit`s after payment). A refund or cancellation takes it back either way.
    class Product < ApplicationRecord
      include PlatformBound
      include SellerScoped
      include Listing
      include Translatable

      self.table_name = 'better_together_billing_products'

      # Subclasses a product may be, by class name. Never resolved from a parameter.
      SUBTYPES = %w[BetterTogether::Billing::Product].freeze
      LIFETIMES = %w[until_used fixed_term].freeze
      TERM_UNITS = %w[day week month year].freeze

      translates :name, type: :string
      translates :description, :summary, type: :text

      belongs_to :tax_category, class_name: 'BetterTogether::Billing::TaxCategory', optional: true
      has_many :prices, -> { order(:created_at) }, class_name: 'BetterTogether::Billing::Price', inverse_of: :product,
                                                   dependent: :restrict_with_error

      # What a purchase includes (roles, feature access, quota allowances); see Entitlements. A quota amount is multiplied by
      # the quantity bought.
      has_many :grants, -> { order(:position, :created_at) }, class_name: 'BetterTogether::Billing::PlanGrant',
                                                              inverse_of: :product, dependent: :restrict_with_error
      has_many :entitlements, class_name: 'BetterTogether::Billing::Entitlement', dependent: :restrict_with_error

      validates :identifier, :name, presence: true
      validates :identifier, uniqueness: { scope: %i[platform_id seller_type seller_id] }
      validates :type, inclusion: { in: SUBTYPES }
      validates :lifetime, inclusion: { in: LIFETIMES }
      validates :term_length, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 120 }, if: :fixed_term?
      validates :term_unit, inclusion: { in: TERM_UNITS }, if: :fixed_term?
      validate :term_only_when_fixed
      validate :tax_category_on_same_platform

      TRANSLATED_FIELDS = %i[name description summary].freeze

      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [*TRANSLATED_FIELDS.flat_map { |field| [field, *I18n.available_locales.map { |locale| :"#{field}_#{locale}" }] },
         :active, :listed, :restricted_to_members, :restricted_to_subscribers, :lifetime, :term_length, :term_unit, :tax_category_id]
      end

      # The identifier is chosen once, when the product is made.
      def self.permitted_attributes_for_create = [:identifier, *permitted_attributes]

      def fixed_term? = lifetime == 'fixed_term'
      def until_used? = lifetime == 'until_used'

      # When what a purchase paid on `time` gives ends: nothing for until used, else the term after it.
      def ends_at_for(time)
        return unless fixed_term?

        time + term_length.public_send(term_unit)
      end

      # What a standard product gives is given when its order is paid and taken back if it is refunded.
      def fulfilled_by_order? = true

      def included_grants = grants

      # The price a buyer is offered now: the newest active one.
      def current_price = prices.active.order(created_at: :desc).first

      private

      # A tax category from another platform would be copied onto an order line, whose key ties it to this platform.
      def tax_category_on_same_platform
        errors.add(:tax_category, :tax_category_other_platform) if tax_category && tax_category.platform_id != platform_id
      end

      def term_only_when_fixed
        return if fixed_term?

        errors.add(:term_length, :not_for_until_used) if term_length.present?
        errors.add(:term_unit, :not_for_until_used) if term_unit.present?
      end
    end
  end
end
