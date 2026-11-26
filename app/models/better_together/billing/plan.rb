# frozen_string_literal: true

module BetterTogether
  module Billing
    # A plan is a product that people subscribe to: it renews through a recurring price, and what it includes is given through
    # the subscription, never through an order of its own. It is sold by the platform or by one of its communities or people
    # (`seller`), see docs/billing/plan_catalog.md. Plan is a subtype of Product (single table, the `type` column), so its name,
    # listing, tax category, grants, agreements and the processor's product are the product's; this adds what only a
    # subscription needs: renewal lead days, grace days, who it may be offered to, and the text shown to participants.
    #
    # Its price is its current recurring Price (see PlanPrice), which can be held by one ONLINE payment processor and/or be
    # payable by methods outside a vendor (`accepted_payment_methods`: cash, cheque, e-transfer, store credit). A plan needs at
    # least one of the two. How it comes to be held by a processor, created here or linked from one that exists, is PlanLinking.
    class Plan < Product # rubocop:disable Metrics/ClassLength
      # Before the concerns below: the typed amount is applied first, then a linked price overrides it.
      include MajorAmount
      include Pricing
      include PaymentMethods
      include PlanPrice
      include PlanLinking
      include SubscriptionTerms

      # What people read about a plan beyond a product's own text, in each supported language.
      translates :beneficiary_label, type: :string, association_name: :plan_string_translations
      translates :participant_summary, type: :text, association_name: :plan_text_translations
      translates :solidarity_description, type: :string, association_name: :plan_string_translations
      # One benefit per line.
      translates :participant_benefits, type: :text, association_name: :plan_text_translations

      # Cheapest first by the plan's recurring price on sale, then by identifier.
      scope :by_price, lambda {
        prices = Price.arel_table
        cheapest = prices.project(prices[:amount_cents].minimum)
                         .where(prices[:product_id].eq(arel_table[:id]).and(prices[:kind].eq('recurring')).and(prices[:active].eq(true))
                                .and(prices[:archived_at].eq(nil)))
        order(Arel::Nodes::Grouping.new(cheapest).asc, arel_table[:identifier].asc)
      }

      DEFAULT_ELIGIBLE_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      PLAN_PRICING_TIERS = %w[standard solidarity_small solidarity_medium solidarity_premium].freeze

      # Not synced to the processor, so a steward can change it whether or not the plan is linked.
      # Local settings that may change after a price is linked: where the plan is shown and who may buy it.
      LISTING_FIELDS = %i[listed restricted_to_members restricted_to_subscribers].freeze

      METADATA_KEYS = [:hosted_access_level, :support_tier, :community_capacity_tier, :pricing_tier,
                       { eligible_billable_owner_types: [] }].freeze
      # The translated text a steward writes, one value per supported language.
      TRANSLATED_FIELDS = %i[name description participant_summary beneficiary_label solidarity_description participant_benefits].freeze

      validate :eligible_owner_types_are_billable
      validate :pricing_tier_within_known_values

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

      # A plan is bought through its price, never as itself, and is never given through an order.
      def fulfilled_by_order? = false
      def renews? = true
      def plan_line? = true

      # A plan is held when it gives a live entitlement or is subscribed to.
      def held_by?(person)
        return false if person.blank? || platform.blank?

        Plans::Holdings.call(platform:, person:).include?(id)
      end

      # ---- catalog presentation ----------------------------------------------------

      def plan_grants = grants

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
