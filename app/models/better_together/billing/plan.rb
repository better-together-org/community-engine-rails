# frozen_string_literal: true

module BetterTogether
  module Billing
    # Catalog entry for a billable Community Engine plan.
    class Plan < ApplicationRecord # rubocop:disable Metrics/ClassLength
      self.table_name = 'better_together_billing_plans'

      BILLING_INTERVALS = %w[month year one_time].freeze
      DEFAULT_ELIGIBLE_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      # Fields that must not change once a Stripe Price has been linked.
      PRICE_IMMUTABLE_FIELDS = %i[amount_cents currency billing_interval].freeze

      has_many :subscriptions,
               class_name: 'BetterTogether::Billing::Subscription',
               foreign_key: :billing_plan_id,
               dependent: :restrict_with_exception,
               inverse_of: :billing_plan

      validates :identifier, :name, :currency, :stripe_price_id, presence: true
      validates :identifier, uniqueness: true
      validates :stripe_price_id, uniqueness: true
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
      validates :currency, length: { is: 3 }
      validates :active, inclusion: { in: [true, false] }
      validate :price_fields_immutable_after_create

      after_commit :enqueue_stripe_sync!, on: %i[create update]

      scope :active, -> { where(active: true) }
      scope :needs_stripe_product_id, -> { where(stripe_product_id: nil).where.not(stripe_price_id: nil) }

      # Permitted attributes for update (price-defining fields excluded after creation).
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [
          :name,
          :description,
          :active,
          { metadata: [:participant_summary, :beneficiary_label, :hosted_access_level,
                       :support_tier, :community_capacity_tier,
                       { participant_benefits: [], eligible_billable_owner_types: [] }] }
        ]
      end

      # Permitted attributes for create (includes immutable price-defining fields).
      def self.permitted_attributes_for_create
        permitted_attributes + %i[identifier stripe_price_id amount_cents currency billing_interval]
      end

      def recurring?
        billing_interval.in?(%w[month year])
      end

      def launch_ready_for_hosted_billing?
        recurring?
      end

      def eligible_for?(billable_owner)
        return false unless billable_owner.present?

        eligible_billable_owner_types.include?(billable_owner.class.name)
      end

      def active_subscription_count
        subscriptions.joins(:pay_subscription)
                     .merge(Pay::Subscription.active)
                     .count
      end

      def eligible_billable_owner_types
        raw_types = Array(metadata['eligible_billable_owner_types']).presence || DEFAULT_ELIGIBLE_OWNER_TYPES

        raw_types.filter_map { |type_name| OwnershipResolver.supported_owner_type_name(type_name) }.presence || DEFAULT_ELIGIBLE_OWNER_TYPES
      end

      def participant_summary
        metadata.to_h['participant_summary'].presence || description.presence || default_participant_summary
      end

      def participant_benefits
        Array(metadata.to_h['participant_benefits']).filter_map do |benefit|
          benefit.to_s.strip.presence
        end
      end

      def beneficiary_label
        metadata.to_h['beneficiary_label'].presence || default_beneficiary_label
      end

      def hosted_access_level
        metadata.to_h['hosted_access_level'].presence
      end

      def support_tier
        metadata.to_h['support_tier'].presence
      end

      def community_capacity_tier
        metadata.to_h['community_capacity_tier'].presence
      end

      private

      def default_participant_summary
        if recurring?
          'Supports hosted access and ongoing stewardship for this Better Together space.'
        else
          'This one-time plan is not currently available in the hosted billing launch path.'
        end
      end

      def default_beneficiary_label
        if eligible_billable_owner_types == [BetterTogether::Person.name]
          'Personal access'
        elsif eligible_billable_owner_types == [BetterTogether::Community.name]
          'Community access'
        else
          'Hosted access'
        end
      end

      def price_fields_immutable_after_create
        return if new_record?
        return if stripe_price_id_was.blank?

        PRICE_IMMUTABLE_FIELDS.each do |field|
          next unless public_send(:"#{field}_changed?")

          errors.add(field, :immutable_after_stripe_link)
        end
      end

      def enqueue_stripe_sync!
        return if stripe_price_id.blank?

        BetterTogether::Billing::SyncPlanToStripeJob.perform_later(id)
      end
    end
  end
end
