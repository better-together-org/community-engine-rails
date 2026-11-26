# frozen_string_literal: true

module BetterTogether
  module Billing
    # Catalog entry for a billable plan: one price on one platform, sold by the platform or
    # by one of its communities or people (`seller`). See docs/billing/plan_catalog.md.
    #
    # The price can be held by one ONLINE payment processor (`processor`, with the
    # processor-side product and price below) and/or be payable by methods outside a
    # vendor (`accepted_payment_methods`: cash, cheque, e-transfer, store credit). A plan
    # needs at least one of the two.
    #
    # A plan comes into being one of two ways:
    # * created here: the steward describes it and the sync job creates the processor-side
    #   product and price (`sync_status` 'pending' until it does);
    # * linked: the steward picks a price that already exists (`link_existing`), and the
    #   price's amount, currency, interval and product are copied from the processor, so
    #   what is shown can never differ from what is charged.
    #
    # Once the processor-side price exists, the fields the processor only accepts at
    # creation are locked here (see #locked_field?).
    class Plan < ApplicationRecord # rubocop:disable Metrics/ClassLength
      include PlatformBound
      include SellerScoped
      include Purchasable
      # Before the concerns below: the typed amount is applied first, then a linked price overrides it.
      include MajorAmount
      include Pricing
      include PaymentMethods
      include ProcessorMirror
      include SubscriptionTerms
      include Listing
      include AgreementTarget
      include Translatable

      self.table_name = 'better_together_billing_plans'

      # What people read about a plan, in each supported language. The metadata hash keeps only what is not language.
      translates :name, :beneficiary_label, type: :string
      translates :description, :participant_summary, type: :text
      translates :solidarity_description, type: :string
      # One benefit per line.
      translates :participant_benefits, type: :text

      DEFAULT_ELIGIBLE_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      PLAN_PRICING_TIERS = %w[standard solidarity_small solidarity_medium solidarity_premium].freeze

      # Not synced to the processor, so a steward can change it whether or not the plan is linked.
      # Local settings that may change after a price is linked: where the plan is shown and who may buy it.
      LISTING_FIELDS = %i[listed restricted_to_members restricted_to_subscribers].freeze

      METADATA_KEYS = [:hosted_access_level, :support_tier, :community_capacity_tier, :pricing_tier,
                       { eligible_billable_owner_types: [] }].freeze
      # The translated text a steward writes, one value per supported language.
      TRANSLATED_FIELDS = %i[name description participant_summary beneficiary_label solidarity_description participant_benefits].freeze

      # How the plan is taxed; none means standard.
      belongs_to :tax_category, class_name: 'BetterTogether::Billing::TaxCategory', optional: true

      # What the plan includes (roles, feature access, quota allowances); see Entitlements.
      has_many :plan_grants, -> { order(:position, :created_at) }, class_name: 'BetterTogether::Billing::PlanGrant', inverse_of: :plan,
                                                                   dependent: :restrict_with_error
      has_many :entitlements, class_name: 'BetterTogether::Billing::Entitlement', dependent: :restrict_with_error

      validates :identifier, :name, presence: true
      validates :identifier, uniqueness: { scope: %i[platform_id seller_type seller_id] }
      validate :eligible_owner_types_are_billable
      validate :pricing_tier_within_known_values
      validate :tax_category_on_same_platform

      # Every plan is a primary one now: what is sold once, an add-on included, is a product.
      scope :primary, -> { all }

      # Permitted attributes for update, as a baseline. Which of them a given plan will
      # accept also depends on what is locked; see #permitted_update_attributes.
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [*with_locales(DESCRIPTIVE_FIELDS + TRANSLATED_FIELDS), *RENEWAL_FIELDS, *LISTING_FIELDS,
         { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
      end

      # Each translated field as one attribute per supported language (name_en, name_fr, ...); the others as they are.
      def self.with_locales(fields)
        fields.uniq.flat_map do |field|
          next field unless TRANSLATED_FIELDS.include?(field)

          [field, *I18n.available_locales.map { |locale| :"#{field}_#{locale}" }]
        end
      end

      # Permitted attributes for create: everything that describes or links the price.
      def self.permitted_attributes_for_create
        permitted_attributes + %i[identifier processor processor_price_id processor_product_id link_existing amount] + PRE_LINK_FIELDS
      end

      # What a steward may change on this plan now, with locked fields left out. The
      # controller permits exactly this, so a crafted request cannot change a locked field.
      def permitted_update_attributes
        fields = DESCRIPTIVE_FIELDS + TRANSLATED_FIELDS + (linked? ? [] : PRE_LINK_FIELDS + %i[amount])
        [*self.class.with_locales(fields.reject do |field|
          locked_field?(field)
        end), *RENEWAL_FIELDS, *LISTING_FIELDS, { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
      end

      # Purchasable: a plan is what a line item is for.
      def purchasable_description = name
      def purchasable_description_in(locale) = name(locale:, fallback: false)
      def purchasable_tax_category = tax_category
      def purchasable? = active?

      # What the order engine asks of a purchasable (see Purchasable): a plan is a subscription that renews, and what it
      # includes is given through the subscription, never through an order of its own.
      def renews? = true
      def plan_line? = true

      # A plan is held when it gives a live entitlement or is subscribed to.
      def held_by?(person)
        return false if person.blank? || platform.blank?

        Plans::Holdings.call(platform:, person:).include?(id)
      end

      # ---- catalog presentation ----------------------------------------------------

      # What it includes, for entitlements (a product answers the same).
      def included_grants = plan_grants

      def eligible_for?(billable_owner)
        return false unless billable_owner.present?

        eligible_billable_owner_types.include?(billable_owner.class.name)
      end

      # What a plan may be offered to. Defaults to Community and Person when none is set.
      def eligible_billable_owner_types
        Array(metadata['eligible_billable_owner_types']).compact_blank.presence || DEFAULT_ELIGIBLE_OWNER_TYPES
      end

      # The owner types a steward may pick: the defaults plus any class that has opted in
      # with Billing::Billable. Names only; nothing is resolved from a string.
      def self.assignable_owner_types
        (DEFAULT_ELIGIBLE_OWNER_TYPES + Billable.model_names.to_a).uniq
      end

      # What to show: the steward's text in the reader's language, else the plan's description, else a default.
      def display_participant_summary
        participant_summary.presence || description.presence || default_participant_summary
      end

      def participant_benefit_list
        participant_benefits.to_s.lines.filter_map { |benefit| benefit.strip.presence }
      end

      def display_beneficiary_label
        beneficiary_label.presence || default_beneficiary_label
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

      def solidarity_tier?
        pricing_tier != 'standard'
      end

      private

      def eligible_owner_types_are_billable
        configured = Array(metadata['eligible_billable_owner_types']).compact_blank
        unknown = configured - self.class.assignable_owner_types
        errors.add(:base, :unknown_owner_types, types: unknown.join(', ')) if unknown.any?
      end

      # A tax category from another platform would be copied onto an order line, whose key ties it to this platform.
      def tax_category_on_same_platform
        errors.add(:tax_category, :tax_category_other_platform) if tax_category && tax_category.platform_id != platform_id
      end

      def pricing_tier_within_known_values
        tier = metadata.to_h['pricing_tier']
        return if tier.blank? || PLAN_PRICING_TIERS.include?(tier)

        errors.add(:base, :invalid_pricing_tier, tier:, allowed: PLAN_PRICING_TIERS.join(', '))
      end

      def default_participant_summary
        I18n.t('better_together.billing.plan_defaults.recurring_participant_summary')
      end

      def default_beneficiary_label
        if eligible_billable_owner_types == [BetterTogether::Person.name]
          I18n.t('better_together.billing.plan_defaults.personal_beneficiary_label')
        elsif eligible_billable_owner_types == [BetterTogether::Community.name]
          I18n.t('better_together.billing.plan_defaults.community_beneficiary_label')
        else
          I18n.t('better_together.billing.plan_defaults.hosted_beneficiary_label')
        end
      end
    end
  end
end
