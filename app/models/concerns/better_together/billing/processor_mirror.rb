# frozen_string_literal: true

module BetterTogether
  module Billing
    # The processor side of something sold: the online processor holding it, the processor-side product and price,
    # whether they are in step (`sync_status`), and which fields lock once linked. Needs the columns `processor`,
    # `processor_product_id`, `processor_price_id`, `sync_status`, `sync_error`, `sync_attempted_at`,
    # `synced_to_processor_at`, `manages_processor_product` and `lock_version`.
    #
    # It comes into being one of two ways:
    # * created here: the steward describes it and the sync job creates the processor-side product and price
    #   (`sync_status` 'pending' until it does);
    # * linked: the steward picks a price that already exists (`link_existing`), and the price's amount, currency,
    #   interval and product are copied from the processor, so what is shown can never differ from what is charged.
    #
    # Once the processor-side price exists, the fields the processor only accepts at creation are locked here (see
    # #locked_field?). The class including it names the job that pushes a change in `processor_sync_job`.
    module ProcessorMirror # rubocop:disable Metrics/ModuleLength
      extend ActiveSupport::Concern

      SYNC_STATUSES = %w[pending synced failed].freeze
      # Fields that define the processor-side price or link to it. Locked once linked unless
      # the adapter says the processor will change them (`field_rules`).
      PRICE_FIELDS = %i[amount_cents currency billing_interval interval_count processor_product_id processor_price_id].freeze
      # Fields editable here that a processor may also hold. Locked after linking only if the
      # adapter says the processor fixes them at creation.
      DESCRIPTIVE_FIELDS = %i[name description active].freeze
      # Changing one of these pushes it to the processor.
      SYNCED_ATTRIBUTES = %w[name description active].freeze
      # Editable while no processor-side price exists yet.
      PRE_LINK_FIELDS = %i[amount_cents currency billing_interval].freeze

      included do
        # Set by code that applies a change that came from the processor, so saving it
        # does not push the same change straight back (loop guard, not persisted).
        attr_accessor :skip_processor_sync

        # The steward chose to link a price that already exists instead of creating one.
        attribute :link_existing, :boolean, default: false

        validates :processor, format: { with: /\A[a-z][a-z0-9_]*\z/ }, allow_blank: true
        validates :processor, presence: true, if: :link_existing
        validates :processor_price_id, presence: true, if: :price_id_required?
        validates :processor_price_id, uniqueness: { scope: :processor }, allow_blank: true
        validates :sync_status, inclusion: { in: SYNC_STATUSES }
        validate :processor_configured_for_platform, on: :create
        validate :linked_price_usable, on: :create
        validate :processor_fields_locked_after_link, on: :update
        validate :product_not_used_by_another_platform

        before_validation :prepare_new_plan, on: :create
        before_validation :load_linked_price, on: :create
        after_commit :enqueue_processor_sync, on: %i[create update]

        scope :needs_processor_product_id, -> { where(processor_product_id: nil).where.not(processor_price_id: nil) }

        SYNC_STATUSES.each do |status|
          define_method(:"sync_#{status}?") { sync_status == status }
        end
      end

      def linked? = processor_price_id.present?

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

      private

      def price_id_required?
        online? && (link_existing || (new_record? && !sync_supported?))
      end

      # Something on a processor that cannot push has nothing to wait for; one that can, starts
      # out waiting for its first push. Choosing an existing product means we did not
      # create it, so we must not rename it.
      def prepare_new_plan
        self.sync_status = sync_supported? ? 'pending' : 'synced'
        self.manages_processor_product = false if processor_product_id.present?
      end

      # Copies the price from the processor when a price id is given. Any price id on a new
      # record is checked this way, whether or not the form said "link": a crafted request
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
        known = SubscriptionTerms::BILLING_INTERVALS.include?(info.interval.to_s)
        known && !info.metered? && info.amount_cents.present? && info.currency.present?
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
      # act on another's catalog. The one deliberate class-level read in this concern.
      def product_not_used_by_another_platform
        return if processor_product_id.blank? || platform_id.blank?
        return unless self.class.where(processor:, processor_product_id:).where.not(platform_id:).exists?

        errors.add(:processor_product_id, :used_by_another_platform)
      end

      def processor_fields_locked_after_link
        return if processor_price_id_was.blank?

        ([:processor] + PRICE_FIELDS + DESCRIPTIVE_FIELDS).each do |field|
          next unless changing?(field)

          errors.add(field, :immutable_after_processor_link) if locked_field?(field, linked: true)
        end
      end

      # Whether a field is about to change; for translated text, in any language.
      def changing?(field)
        changed.any? { |key| key == field.to_s || key.start_with?("#{field}_") }
      end

      def synced_change? = saved_changes.keys.any? { |key| synced_key?(key) }

      def synced_key?(key)
        SYNCED_ATTRIBUTES.any? { |attribute| key == attribute || key.start_with?("#{attribute}_") }
      end

      # Pushes a created or renamed/described/(de)activated record to the processor. Never for
      # a change core is applying itself, never when the processor cannot push, and not for one
      # that was just linked to a price that already exists (nothing to create).
      def enqueue_processor_sync
        return if skip_processor_sync || !sync_supported?
        return if previously_new_record? && sync_synced?
        return unless previously_new_record? || synced_change?

        BetterTogether::Billing::SyncPlanJob.perform_later(id)
      end
    end
  end
end
