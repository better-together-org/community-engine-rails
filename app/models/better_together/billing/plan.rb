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

      PLAN_PRICING_TIERS = %w[standard solidarity_small solidarity_medium solidarity_premium].freeze
      SYNC_STATUSES = %w[pending synced failed].freeze

      # Fields that define the processor-side price or link to it. Locked once linked unless
      # the adapter says the processor will change them (`field_rules`).
      PRICE_FIELDS = %i[amount_cents currency billing_interval processor_product_id processor_price_id].freeze
      # Fields editable here that a processor may also hold. Locked after linking only if the
      # adapter says the processor fixes them at creation.
      DESCRIPTIVE_FIELDS = %i[name description active].freeze
      # Changing one of these pushes the plan to the processor.
      SYNCED_ATTRIBUTES = %w[name description active].freeze
      # Editable while no processor-side price exists yet.
      PRE_LINK_FIELDS = %i[amount_cents currency billing_interval].freeze

      # Not part of the processor-backed price, so editable at any time.
      PAYMENT_METHOD_PARAMS = { accepted_payment_methods: [] }.freeze

      METADATA_KEYS = [:participant_summary, :beneficiary_label, :hosted_access_level,
                       :support_tier, :community_capacity_tier,
                       :pricing_tier, :solidarity_description,
                       { participant_benefits: [], eligible_billable_owner_types: [] }].freeze

      # Set by code that applies a change that came from the processor, so saving it
      # does not push the same change straight back (loop guard, not persisted).
      attr_accessor :skip_processor_sync

      # The steward chose to link a price that already exists instead of creating one.
      attribute :link_existing, :boolean, default: false

      before_validation :normalize_payment_fields

      validates :identifier, :name, :currency, presence: true
      validates :identifier, uniqueness: { scope: %i[platform_id seller_type seller_id] }
      validates :processor, format: { with: /\A[a-z][a-z0-9_]*\z/ }, allow_blank: true
      validates :processor, presence: true, if: :link_existing
      validate :payable_some_way
      validate :accepted_methods_are_not_online_processors
      validates :processor_price_id, presence: true, if: :price_id_required?
      validates :processor_price_id, uniqueness: { scope: :processor }, allow_blank: true
      validates :sync_status, inclusion: { in: SYNC_STATUSES }
      validate :processor_configured_for_platform, on: :create
      validate :linked_price_usable, on: :create
      validates :amount_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
      validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
      validates :currency, length: { is: 3 }, inclusion: { in: SUPPORTED_CURRENCY_CODES }
      validates :active, inclusion: { in: [true, false] }
      validate :processor_fields_locked_after_link, on: :update
      validate :product_not_used_by_another_platform
      validate :eligible_owner_types_are_billable
      validate :pricing_tier_within_known_values

      before_validation :prepare_new_plan, on: :create
      before_validation :load_linked_price, on: :create
      after_commit :enqueue_processor_sync, on: %i[create update]

      scope :active, -> { where(active: true) }
      scope :needs_processor_product_id, -> { where(processor_product_id: nil).where.not(processor_price_id: nil) }

      # Permitted attributes for update, as a baseline. Which of them a given plan will
      # accept also depends on what is locked; see #permitted_update_attributes.
      def self.permitted_attributes(id: false, destroy: false, **) # rubocop:disable Lint/UnusedMethodArgument
        [*DESCRIPTIVE_FIELDS, { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
      end

      # Permitted attributes for create: everything that describes or links the price.
      def self.permitted_attributes_for_create
        permitted_attributes + %i[identifier processor processor_price_id processor_product_id link_existing] + PRE_LINK_FIELDS
      end

      # What a steward may change on this plan now, with locked fields left out. The
      # controller permits exactly this, so a crafted request cannot change a locked field.
      def permitted_update_attributes
        fields = DESCRIPTIVE_FIELDS + (linked? ? [] : PRE_LINK_FIELDS)
        [*fields.reject { |field| locked_field?(field) }, { metadata: METADATA_KEYS }.merge(PAYMENT_METHOD_PARAMS)]
      end

      def recurring?
        billing_interval.in?(%w[month year])
      end

      def launch_ready_for_hosted_billing?
        recurring?
      end

      # ---- the processor side ----------------------------------------------------

      def linked? = processor_price_id.present?

      # Purchasable: a plan is what an order line is for.
      def purchasable_description = name
      def purchasable_amount_cents = amount_cents
      def purchasable_currency = currency
      def purchasable? = active?

      # Held by an online payment processor (as opposed to paid only by cash, cheque,
      # e-transfer or store credit).
      def online? = processor.present?

      # Every way this plan can be paid: its online processor, then the others.
      def payment_methods = [processor.presence, *accepted_payment_methods].compact.uniq

      SYNC_STATUSES.each do |status|
        define_method(:"sync_#{status}?") { sync_status == status }
      end

      def processor_adapter
        Billing.processor_adapter(processor) if processor.present?
      end

      def processor_context
        Configuration.context_for(platform, processor) if platform.present? && processor.present?
      end

      # True when the processor can create and update plans for this platform, so the
      # plan is pushed rather than only recorded.
      def sync_supported?
        processor_context.present? && processor_adapter&.supports?(:plan_sync) ? true : false
      end

      def field_rules
        (processor_adapter&.field_rules(:plan) || {}).to_h.symbolize_keys
      end

      # Whether a field is fixed here because the processor will not change it.
      #
      # Fields that define the price (and the processor itself) are locked once linked
      # unless the adapter declares them `:updatable`; a processor that says nothing is
      # assumed to fix them at creation. Descriptive fields stay editable unless the
      # adapter declares them `:create_only`.
      def locked_field?(field, linked: linked?)
        return false unless linked

        field = field.to_sym
        rule = field_rules[field]
        return rule != :updatable if PRICE_FIELDS.include?(field) || field == :processor

        rule == :create_only
      end

      # Idempotency key for the next push, so a retried job cannot create a second
      # product or price. Core owns it; the adapter passes it to every processor write.
      def sync_idempotency_key
        linked? ? "bt-plan-update-#{id}-#{lock_version}" : "bt-plan-create-#{id}"
      end

      # Stores what the adapter did. It writes no callback-bearing attribute, so it can never
      # trigger another push.
      #
      # These write status columns directly: the processor has already acted, so the ids it
      # returned must be kept even if something unrelated about the plan is invalid, and
      # recording a failure must not itself fail. Uniqueness of a price id is still held by
      # the database.
      def apply_sync_result!(result)
        now = Time.current
        update_columns( # rubocop:disable Rails/SkipsModelValidations
          processor_product_id: result.product_id, processor_price_id: result.price.price_id, sync_status: 'synced',
          sync_error: nil, sync_attempted_at: now, synced_to_processor_at: now, updated_at: now
        )
      end

      def record_sync_failure!(code)
        now = Time.current
        update_columns(sync_status: 'failed', sync_error: code.to_s.first(60), sync_attempted_at: now, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
      end

      def restart_sync!
        update_columns(sync_status: 'pending', sync_error: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
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

      # An installed method that does not go through a vendor (settlement manual or internal).
      def self.offline_method?(name) = Billing.offline_method?(name)

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

      def price_id_required?
        online? && (link_existing || (new_record? && !sync_supported?))
      end

      # An empty processor means "none", stored as NULL like every other absent value.
      def normalize_payment_fields
        self.processor = processor.presence
        self.accepted_payment_methods = Array(accepted_payment_methods).map { |name| name.to_s.strip }.compact_blank.uniq
      end

      # A plan nobody could pay for is a mistake: it needs an online processor or at least
      # one other way to pay.
      def payable_some_way
        errors.add(:base, :no_payment_method) if processor.blank? && accepted_payment_methods.empty?
      end

      # Accepted methods are the ones outside a vendor. They must be installed, and the online
      # processor is chosen in its own field, so it does not belong in this list.
      def accepted_methods_are_not_online_processors
        accepted_payment_methods.each do |name|
          next if name != processor && self.class.offline_method?(name)

          errors.add(:accepted_payment_methods, :not_an_offline_method, method: name)
        end
      end

      # A plan on a processor that cannot push has nothing to wait for; one that can, starts
      # out waiting for its first push. Choosing an existing product means we did not
      # create it, so we must not rename it.
      def prepare_new_plan
        self.sync_status = sync_supported? ? 'pending' : 'synced'
        self.manages_processor_product = false if processor_product_id.present?
      end

      # Copies the price from the processor when a price id is given. Any price id on a new
      # plan is checked this way, whether or not the form said "link": a crafted request
      # must not be able to attach a price from another account without it being looked up.
      # A failed lookup does not link: the problem is reported on the price id.
      def load_linked_price
        @link_error = nil
        return unless processor_price_id.present? && sync_supported?

        copy_price(processor_adapter.fetch_price(context: processor_context, processor_price_id:))
      rescue ProcessorAdapter::LookupError
        @link_error = :lookup_failed
      rescue StandardError => e
        Rails.logger.error("[billing] price lookup failed for a new plan: #{e.class}")
        BetterTogether.report_error(e, context: { processor:, platform_id: })
        @link_error = :lookup_failed
      end

      def copy_price(info)
        return @link_error = :not_found_at_processor if info.nil?
        return @link_error = :price_inactive unless info.active?

        assign_attributes(
          { amount_cents: info.amount_cents, currency: info.currency, billing_interval: info.interval,
            processor_product_id: info.product_id }.compact
        )
        self.manages_processor_product = false
        self.sync_status = 'synced'
        self.synced_to_processor_at = Time.current
      end

      def linked_price_usable
        errors.add(:processor_price_id, @link_error) if @link_error
      end

      def processor_configured_for_platform
        return if processor.blank?
        return errors.add(:processor, :not_installed) unless Billing.processor_names.map(&:to_s).include?(processor)

        errors.add(:processor, :not_configured) unless processor_context
      end

      # A processor-side product can be used by several of one platform's plans (a monthly
      # and a yearly price), but never by another platform's: that would let one tenant
      # act on another's catalog. The one deliberate class-level read in this model.
      def product_not_used_by_another_platform
        return if processor_product_id.blank? || platform_id.blank?
        return unless self.class.where(processor:, processor_product_id:).where.not(platform_id:).exists?

        errors.add(:processor_product_id, :used_by_another_platform)
      end

      def processor_fields_locked_after_link
        return if processor_price_id_was.blank?

        ([:processor] + PRICE_FIELDS + DESCRIPTIVE_FIELDS).each do |field|
          next unless will_save_change_to_attribute?(field)

          errors.add(field, :immutable_after_processor_link) if locked_field?(field, linked: true)
        end
      end

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

      # Pushes a created or renamed/described/(de)activated plan to the processor. Never for
      # a change core is applying itself, never when the processor cannot push, and not for a
      # plan that was just linked to a price that already exists (nothing to create).
      def enqueue_processor_sync
        return if skip_processor_sync || !sync_supported?
        return if previously_new_record? && sync_synced?
        return unless previously_new_record? || saved_changes.keys.intersect?(SYNCED_ATTRIBUTES)

        BetterTogether::Billing::SyncPlanJob.perform_later(id)
      end
    end
  end
end
