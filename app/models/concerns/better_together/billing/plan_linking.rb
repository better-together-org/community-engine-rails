# frozen_string_literal: true

module BetterTogether
  module Billing
    # How a plan's recurring price comes to be held by an online processor, and which fields lock once it is. The push itself is
    # ProductMirror's; this adds the choice a plan has that other products do not.
    #
    # It comes into being one of two ways:
    # * created here: the steward describes it and the sync job creates the processor-side product and price
    #   (`sync_status` 'pending' until it does);
    # * linked: the steward picks a price that already exists (`link_existing`), and the price's amount, currency,
    #   interval and product are copied from the processor, so what is shown can never differ from what is charged.
    #
    # Once the processor-side price exists, the fields the processor only accepts at creation are locked here (see
    # #locked_field?). Needs the price attributes of PlanPrice.
    module PlanLinking
      extend ActiveSupport::Concern

      # Fields that define the processor-side price or link to it. Locked once linked unless
      # the adapter says the processor will change them (`field_rules`).
      PRICE_FIELDS = %i[amount_cents currency billing_interval interval_count processor_product_id processor_price_id].freeze
      # Fields editable here that a processor may also hold. Locked after linking only if the
      # adapter says the processor fixes them at creation.
      DESCRIPTIVE_FIELDS = %i[name description active].freeze
      # Editable while no processor-side price exists yet.
      PRE_LINK_FIELDS = %i[amount_cents currency billing_interval].freeze

      included do
        # The steward chose to link a price that already exists instead of creating one.
        attribute :link_existing, :boolean, default: false

        validates :processor, presence: true, if: :link_existing
        validates :processor_price_id, presence: true, if: :price_id_required?
        validate :processor_price_id_unused
        validate :linked_price_usable, on: :create
        validate :processor_fields_locked_after_link, on: :update
        validate :product_not_used_by_another_platform

        before_validation :prepare_new_plan, on: :create
        before_validation :load_linked_price, on: :create
      end

      def linked? = processor_price_id.present?

      # A plan is pushed by any adapter that holds plans, whichever contract it speaks (see CatalogSync).
      def sync_supported?
        processor_context.present? && processor_adapter&.supports?(:plan_sync) ? true : false
      end

      # What the adapter says about each field: :updatable, :create_only, or absent for locked once linked.
      def field_rules
        (processor_adapter&.field_rules(:plan) || {}).to_h.symbolize_keys
      end

      # Whether a steward can no longer change a field here. `linked:` lets a caller ask as if the price were linked.
      def locked_field?(field, linked: linked?)
        return false unless linked

        field = field.to_sym
        rule = field_rules[field]
        return rule != :updatable if PRICE_FIELDS.include?(field) || field == :processor

        rule == :create_only
      end

      # A plan that arrives already synced (a linked price) is not pushed on creation; later edits are.
      def queue_processor_sync
        return if previously_new_record? && sync_synced?

        super
      end

      def restart_sync!
        update_columns(sync_status: 'pending', sync_error: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      end

      private

      # Online with no way to create the price here (no adapter that does), or a linked one: the id is required.
      def price_id_required?
        online? && (link_existing || (new_record? && !sync_supported?))
      end

      def prepare_new_plan
        self.sync_status = sync_supported? && !link_existing ? 'pending' : 'synced'
        self.manages_processor_product = false if processor_product_id.present?
      end

      # Linking reads the price from the processor and copies it over what the steward typed, so the plan shows what is charged.
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
        # A price core cannot represent (weekly, daily, metered, or one with no interval at all) is
        # refused, never quietly shown as a monthly price of nothing.
        return @link_error = :unsupported_price unless representable?(info)

        assign_attributes(
          { amount_cents: info.amount_cents, currency: info.currency, billing_interval: info.interval,
            interval_count: info.interval_count, processor_product_id: info.product_id }.compact
        )
        self.manages_processor_product = false
        self.sync_status = 'synced'
        self.synced_to_processor_at = Time.current
      end

      def representable?(info)
        known = Price::INTERVALS.include?(info.interval.to_s)
        known && !info.metered? && info.amount_cents.present? && info.currency.present?
      end

      def linked_price_usable
        errors.add(:processor_price_id, @link_error) if @link_error
      end

      # A processor price is one plan's: the same price cannot be linked twice on one processor.
      def processor_price_id_unused
        return if processor_price_id.blank? || !processor_price_id_changed?

        taken = Price.joins(:product).where(processor_price_id:, product: { processor: }).where.not(product_id: id)
        errors.add(:processor_price_id, :taken) if taken.exists?
      end

      def product_not_used_by_another_platform
        return if processor_product_id.blank? || platform_id.blank?
        return unless Product.where(processor:, processor_product_id:).where.not(platform_id:).exists?

        errors.add(:processor_product_id, :used_by_another_platform)
      end

      def processor_fields_locked_after_link
        return if processor_price_id_was.blank?

        ([:processor] + PRICE_FIELDS + DESCRIPTIVE_FIELDS).each do |field|
          next unless changing?(field)

          errors.add(field, :immutable_after_processor_link) if locked_field?(field, linked: true)
        end
      end

      # A translated field changes as `name_en`, `name_fr`, so any column that begins with the field counts.
      def changing?(field)
        changed.any? { |key| key == field.to_s || key.start_with?("#{field}_") }
      end
    end
  end
end
