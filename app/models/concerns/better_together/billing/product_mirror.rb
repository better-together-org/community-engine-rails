# frozen_string_literal: true

module BetterTogether
  module Billing
    # A product held by an online processor: which processor, its processor-side product id, and the state of the last push
    # (`sync_status`). Its prices carry their own processor price ids. Needs the columns `processor`, `processor_product_id`,
    # `sync_status`, `sync_error`, `sync_attempted_at` and `synced_to_processor_at`.
    #
    # A product needs no processor to be sold through one: without it, checkout sends its price inline (Checkout::Lines).
    # Naming a processor asks it to keep a copy in its own catalog, which only an adapter at contract version 2 can do.
    module ProductMirror
      extend ActiveSupport::Concern

      SYNC_STATUSES = %w[pending synced failed].freeze
      # Changing one of these pushes it to the processor.
      SYNCED_ATTRIBUTES = %w[name description active tax_category_id].freeze

      included do
        # Set by code applying a change that came from the processor, so saving it does not push it straight back.
        attr_accessor :skip_processor_sync

        validates :processor, format: { with: /\A[a-z][a-z0-9_]*\z/ }, allow_blank: true
        validates :sync_status, inclusion: { in: SYNC_STATUSES }
        validate :processor_installed_and_configured, if: -> { processor.present? && (new_record? || processor_changed?) }

        before_create { self.sync_status = sync_supported? && manages_processor_product ? 'pending' : 'synced' }
        before_update :unlink_from_previous_processor, if: :processor_changed?
        after_commit :queue_processor_sync, on: %i[create update]

        SYNC_STATUSES.each { |status| define_method(:"sync_#{status}?") { sync_status == status } }
      end

      def online? = processor.present?

      def processor_adapter = (Billing.processor_adapter(processor) if processor.present?)

      def processor_context = (Configuration.context_for(platform, processor) if platform.present? && processor.present?)

      # True when the processor can hold this product here: it is configured for the platform and its adapter takes a catalog item.
      def sync_supported?
        adapter = processor_adapter
        processor_context.present? && adapter&.supports?(:plan_sync) && adapter.catalog_aware?
      end

      # Prices that exist here but not yet on the processor.
      def unsynced_prices = prices.reject { |price| price.processor_price_id.present? }

      # Core owns it, so a retried job cannot create a second product or price; it changes with the product and the prices waiting.
      def sync_idempotency_key
        "bt-product-#{id}-#{lock_version}-#{Digest::SHA256.hexdigest(unsynced_prices.map(&:id).sort.join(','))[0, 8]}"
      end

      # Pushes the product and its prices now, in the background. Used when a price is added too.
      def queue_processor_sync
        return if skip_processor_sync || !sync_supported?
        return unless previously_new_record? || synced_change? || unsynced_prices.any?

        update_columns(sync_status: 'pending', sync_error: nil) unless sync_pending? # rubocop:disable Rails/SkipsModelValidations
        BetterTogether::Billing::SyncProductJob.perform_later(id)
      end

      # Stores what the adapter did: the processor's product id, and the id of each price it answered for. Writes columns directly,
      # so it can never trigger another push; the processor has already acted, so what it returned is kept.
      def apply_sync_result!(result)
        now = Time.current
        transaction do
          update_columns(processor_product_id: result.product_id, sync_status: 'synced', sync_error: nil, sync_attempted_at: now, # rubocop:disable Rails/SkipsModelValidations
                         synced_to_processor_at: now, updated_at: now)
          prices.each do |price|
            info = result.price_for(price.id)
            price.update_columns(processor_price_id: info.price_id) if info && price.processor_price_id.blank? # rubocop:disable Rails/SkipsModelValidations
          end
        end
      end

      def record_sync_failure!(code)
        now = Time.current
        update_columns(sync_status: 'failed', sync_error: code.to_s.first(60), sync_attempted_at: now, updated_at: now) # rubocop:disable Rails/SkipsModelValidations
      end

      private

      # Ids belong to the processor that issued them, so moving to another forgets them (and the prices' ids) and has the new one
      # create its own copy. Writes the price columns directly: they are mirror state, not something a steward edits.
      def unlink_from_previous_processor
        self.processor_product_id = nil
        self.sync_status = 'pending'
        prices.update_all(processor_price_id: nil) # rubocop:disable Rails/SkipsModelValidations
        prices.reset
      end

      def synced_change?
        return true if saved_changes.key?('processor')

        saved_changes.keys.any? { |key| SYNCED_ATTRIBUTES.any? { |attribute| key == attribute || key.start_with?("#{attribute}_") } }
      end

      def processor_installed_and_configured
        return errors.add(:processor, :not_installed) unless Billing.processor_names.map(&:to_s).include?(processor)

        errors.add(:processor, :not_configured) unless processor_context
      end
    end
  end
end
