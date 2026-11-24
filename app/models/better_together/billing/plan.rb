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
      include Pricing
      include PaymentMethods
      include ProcessorMirror
      include SubscriptionTerms
      include Listing
      include AgreementTarget
      include MajorAmount
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
      # Local settings that may change after a price is linked: where the plan is shown, who may buy it, and whether it is an add-on.
      LISTING_FIELDS = %i[listed restricted_to_members restricted_to_subscribers add_on].freeze

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

      # For a primary plan: the add-ons set to extend it. For an add-on: the plans it extends (none means every primary plan).
      has_many :add_on_links, class_name: 'BetterTogether::Billing::PlanAddOn', foreign_key: :plan_id, inverse_of: :plan,
                              dependent: :destroy
      has_many :target_links, class_name: 'BetterTogether::Billing::PlanAddOn', foreign_key: :add_on_id, inverse_of: :add_on,
                              dependent: :destroy
      has_many :target_plans, through: :target_links, source: :plan

      validates :identifier, :name, presence: true
      validates :identifier, uniqueness: { scope: %i[platform_id seller_type seller_id] }
      validate :eligible_owner_types_are_billable
      validate :pricing_tier_within_known_values
      validate :add_on_is_a_plain_extra

      before_validation :clear_targets_unless_add_on

      # An add-on is only sold on another plan's order; the plans people buy by themselves are the primary ones.
      scope :add_on, -> { where(add_on: true) }
      scope :primary, -> { where(add_on: false) }
      # The add-ons offered with `plan`: those set to extend it, and those that extend every plan (no links).
      scope :add_ons_for, lambda { |plan|
        add_on.where(id: PlanAddOn.where(plan_id: plan.id).select(:add_on_id))
              .or(add_on.where.not(id: PlanAddOn.select(:add_on_id)))
      }

      # Permitted attributes for update, as a baseline. Which of them a given plan will
      # accept also depends on what is locked; see #permitted_update_attributes.
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [*with_locales(DESCRIPTIVE_FIELDS + TRANSLATED_FIELDS), *RENEWAL_FIELDS, *LISTING_FIELDS,
         { target_plan_ids: [] }, { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
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
        end), *RENEWAL_FIELDS, *LISTING_FIELDS, { target_plan_ids: [] }, { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
      end

      # Purchasable: a plan is what a line item is for.
      def purchasable_description = name
      def purchasable_description_in(locale) = name(locale:, fallback: false)
      def purchasable_tax_category = tax_category
      def purchasable? = active?

      # What the order engine asks of a purchasable (see Purchasable): a plan that renews is a subscription, an add-on is an
      # extra, and a one-time plan with something to give is fulfilled through its own order.
      def renews? = recurring?
      def extra? = add_on?
      def plan_line? = true
      def fulfilled_by_order? = !recurring? && !add_on?

      # A primary plan is held when it gives a live entitlement, is subscribed to, or was bought once and the order stands.
      def held_by?(person)
        return false if add_on? || person.blank? || platform.blank?

        Plans::Holdings.call(platform:, person:).include?(id)
      end

      # ---- catalog presentation ----------------------------------------------------

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

      # An add-on is a plain one-off extra: it does not renew and includes nothing of its own (what a plan gives is a plan's).
      # Only an add-on extends other plans; ticking targets and then un-ticking add-on leaves none behind.
      def clear_targets_unless_add_on
        self.target_plan_ids = [] if !add_on? && target_links.any?
      end

      def add_on_is_a_plain_extra
        return unless add_on?

        errors.add(:add_on, :add_on_cannot_renew) if recurring?
        add_on_persisted_errors if persisted?
      end

      def add_on_persisted_errors
        errors.add(:add_on, :add_on_has_grants) if plan_grants.exists?
        errors.add(:add_on, :add_on_locked_by_orders) if add_on_changed? && referenced_by_order_lines?
      end

      # Whether any order line already points at this plan; a change of kind would rewrite what those buyers bought.
      def referenced_by_order_lines?
        BetterTogether::Billing::LineItem.exists?(purchasable: self)
      end

      def pricing_tier_within_known_values
        tier = metadata.to_h['pricing_tier']
        return if tier.blank? || PLAN_PRICING_TIERS.include?(tier)

        errors.add(:base, :invalid_pricing_tier, tier:, allowed: PLAN_PRICING_TIERS.join(', '))
      end

      def default_participant_summary
        if recurring?
          I18n.t('better_together.billing.plan_defaults.recurring_participant_summary')
        else
          I18n.t('better_together.billing.plan_defaults.one_time_participant_summary')
        end
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
