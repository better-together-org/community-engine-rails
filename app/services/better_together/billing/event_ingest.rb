# frozen_string_literal: true

module BetterTogether
  module Billing
    # Records a processor event once, for one platform. A duplicate delivery returns the
    # existing row with created: false, so the caller does not log it twice.
    class EventIngest
      Ingested = Struct.new(:event, :created, keyword_init: true)

      # The event is already logged for a different platform. Vendor event ids are
      # globally unique, so this means one delivery was attributed to two tenants; it is
      # refused rather than handed to the wrong one.
      class PlatformConflictError < StandardError; end

      def self.call(...) = new.call(...)

      # The lookup is deliberately not scoped to a platform: the dedupe key is
      # (processor, event_id), which is globally unique, and a hit on another platform
      # is a conflict to refuse, not a row to return.
      def call(processor:, platform:, event_id:, event_type:, payload:, occurred_at: nil) # rubocop:disable Metrics/ParameterLists
        key = { processor: processor.to_s, event_id: event_id.to_s }
        existing = BetterTogether::Billing::Event.find_by(key)
        return duplicate(existing, platform) if existing

        create_event(key, platform, event_type, payload, occurred_at)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        raced = BetterTogether::Billing::Event.find_by(key)
        raise unless raced

        duplicate(raced, platform)
      end

      private

      def duplicate(existing, platform)
        unless existing.platform_id == platform.id
          raise PlatformConflictError, "event #{existing.event_id} is already logged for another platform"
        end

        Ingested.new(event: existing, created: false)
      end

      def create_event(key, platform, event_type, payload, occurred_at)
        event = BetterTogether::Billing::Event.create!(
          **key, platform:, event_type:, payload: payload.to_h, first_received_at: Time.current,
                 processor_event_created_at: occurred_at
        )
        Ingested.new(event:, created: true)
      end
    end
  end
end
