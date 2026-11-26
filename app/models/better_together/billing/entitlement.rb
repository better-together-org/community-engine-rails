# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a person or community has now because of a plan they pay for: its source (a Pay subscription, or a
    # paid one-time order), what it is for, and where it stands. The status follows the source and nothing else:
    #
    #   active   paid up (a subscription running, an order paid)
    #   grace    the subscription is past due; everything still works and the holder is warned
    #   lapsed   the grace ran out or the subscription ended; what the entitlement made was taken away
    #   revoked  the order was refunded
    #
    # See Entitlements::State for how a Pay subscription decides it. Reach it through its platform.
    class Entitlement < ApplicationRecord
      include PlatformBound
      include Subjectable

      self.table_name = 'better_together_billing_entitlements'

      STATUSES = %w[active grace lapsed revoked].freeze
      LIVE = %w[active grace].freeze

      # What gave it: a product, which may be a plan. `quantity` is how many were bought (not for a plan).
      belongs_to :product, class_name: 'BetterTogether::Billing::Product', optional: false
      belongs_to :beneficiary, polymorphic: true, optional: false
      belongs_to :pay_subscription, class_name: 'Pay::Subscription', optional: true
      belongs_to :order, class_name: 'BetterTogether::Billing::Order', optional: true
      has_many :grants, class_name: 'BetterTogether::Billing::EntitlementGrant', inverse_of: :entitlement, dependent: :restrict_with_error

      attr_readonly :product_id, :quantity, :beneficiary_type, :beneficiary_id, :pay_subscription_id, :order_id

      validates :status, inclusion: { in: STATUSES }
      validates :starts_at, presence: true
      validates :quantity, numericality: { only_integer: true, greater_than: 0 }
      validate :exactly_one_source
      validate :beneficiary_allowed
      validate :same_platform

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end
      scope :live, -> { where(status: LIVE) }

      def live? = LIVE.include?(status)

      # The plan, when a plan gave it.
      def plan = (product if product.is_a?(Plan))

      def plan=(record)
        self.product = record
      end

      # The product that gave it, and its name for the holder to read.
      def item = product
      def item_name = item&.name

      # Who pays: the subscriber's payer, or the buyer of the order. They are the ones told about it.
      def payer = pay_subscription ? pay_subscription.customer.owner : order&.buyer

      private

      def exactly_one_source
        errors.add(:base, :one_source) unless pay_subscription_id.present? ^ order_id.present?
      end

      def beneficiary_allowed
        errors.add(:beneficiary_type, :inclusion) unless SellerScoped.assignable_types.include?(beneficiary_type)
      end

      def same_platform
        { product:, order:, pay_subscription: }.each do |name, record|
          errors.add(name, :platform_owner_mismatch) if record && record.platform_id != platform_id
        end
      end
    end
  end
end
