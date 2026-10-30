# frozen_string_literal: true

module BetterTogether
  module Billing
    # Catalog entry for a billable Community Engine plan.
    class Plan < ApplicationRecord # rubocop:disable Metrics/ClassLength
      self.table_name = 'better_together_billing_plans'

      BILLING_INTERVALS = %w[month year one_time].freeze
      DEFAULT_ELIGIBLE_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      # ISO 4217 alpha-3 codes this platform accepts for a Plan's price.
      # A superset of Billing::Currency::SYMBOLS: a currency can be billed
      # without a curated symbol (display falls back to the raw code).
      SUPPORTED_CURRENCY_CODES = %w[
        AUD BRL CAD CHF CNY DKK EUR GBP HKD INR
        JPY KRW MXN NOK NZD PLN SEK SGD USD ZAR
      ].freeze

      # Fields that must not change once a processor price has been linked.
      PRICE_IMMUTABLE_FIELDS = %i[amount_cents currency billing_interval].freeze

      PLAN_PRICING_TIERS = %w[standard solidarity_small solidarity_medium solidarity_premium].freeze

      # Set by code that applies a processor-originated change, so saving it
      # does not push the same change straight back (loop guard, not persisted).
      attr_accessor :skip_processor_sync

      validates :identifier, :name, :currency, :processor, :processor_price_id, presence: true
      validates :identifier, uniqueness: true
      validates :processor_price_id, uniqueness: { scope: :processor }
      validates :processor, format: { with: /\A[a-z][a-z0-9_]*\z/ }
      validate :processor_registered, on: :create
      validate :processor_price_exists, on: :create
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
      validates :currency, length: { is: 3 }, inclusion: { in: SUPPORTED_CURRENCY_CODES }
      validates :active, inclusion: { in: [true, false] }
      validate :price_fields_immutable_after_create
      validate :pricing_tier_within_known_values

      after_commit :enqueue_processor_sync, on: %i[create update]

      scope :active, -> { where(active: true) }
      scope :needs_processor_product_id, -> { where(processor_product_id: nil).where.not(processor_price_id: nil) }

      # Permitted attributes for update (price-defining fields excluded after creation).
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [
          :name,
          :description,
          :active,
          { metadata: [:participant_summary, :beneficiary_label, :hosted_access_level,
                       :support_tier, :community_capacity_tier,
                       :pricing_tier, :solidarity_description,
                       { participant_benefits: [], eligible_billable_owner_types: [] }] }
        ]
      end

      # Permitted attributes for create (includes immutable price-defining fields).
      def self.permitted_attributes_for_create
        permitted_attributes + %i[identifier processor processor_price_id amount_cents currency billing_interval]
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

      def eligible_billable_owner_types
        raw_types = Array(metadata['eligible_billable_owner_types']).presence || DEFAULT_ELIGIBLE_OWNER_TYPES

        raw_types.select { |type_name| BetterTogether::Billing::Billable.model?(type_name) }.presence || DEFAULT_ELIGIBLE_OWNER_TYPES
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

      def pricing_tier
        metadata.to_h['pricing_tier'].presence || 'standard'
      end

      def solidarity_description
        metadata.to_h['solidarity_description'].presence
      end

      def solidarity_tier?
        pricing_tier != 'standard'
      end

      private

      def default_participant_summary
        if recurring?
          I18n.t(
            'better_together.billing.plan_defaults.recurring_participant_summary',
            default: 'Supports hosted access and ongoing stewardship for this Better Together space.'
          )
        else
          I18n.t(
            'better_together.billing.plan_defaults.one_time_participant_summary',
            default: 'This one-time plan is not currently available in the hosted billing launch path.'
          )
        end
      end

      def default_beneficiary_label
        if eligible_billable_owner_types == [BetterTogether::Person.name]
          I18n.t('better_together.billing.plan_defaults.personal_beneficiary_label', default: 'Personal access')
        elsif eligible_billable_owner_types == [BetterTogether::Community.name]
          I18n.t('better_together.billing.plan_defaults.community_beneficiary_label', default: 'Community access')
        else
          I18n.t('better_together.billing.plan_defaults.hosted_beneficiary_label', default: 'Hosted access')
        end
      end

      def pricing_tier_within_known_values
        tier = metadata.to_h['pricing_tier']
        return if tier.blank? || PLAN_PRICING_TIERS.include?(tier)

        errors.add(:base, :invalid_pricing_tier, tier:, allowed: PLAN_PRICING_TIERS.join(', '))
      end

      def price_fields_immutable_after_create
        return if new_record?
        return if processor_price_id_was.blank?

        PRICE_IMMUTABLE_FIELDS.each do |field|
          next unless public_send(:"#{field}_changed?")

          errors.add(field, :immutable_after_processor_link)
        end
      end

      def processor_adapter
        BetterTogether::Billing.processor_adapter(processor) if processor.present?
      end

      def processor_registered
        return if processor.blank? || BetterTogether::Billing.processor_names.include?(processor.to_sym)

        errors.add(:processor, :not_installed)
      end

      # Stops a steward linking a price that belongs to another account.
      def processor_price_exists
        adapter = processor_adapter
        return unless adapter&.supports?(:plan_sync)
        return if adapter.verify_price(processor_price_id:)

        errors.add(:processor_price_id, :not_found_at_processor)
      rescue StandardError
        errors.add(:processor_price_id, :lookup_failed)
      end

      def enqueue_processor_sync
        return if skip_processor_sync || processor_price_id.blank?
        return unless processor_adapter&.supports?(:plan_sync)

        BetterTogether::Billing::SyncPlanJob.perform_later(id)
      end
    end
  end
end
