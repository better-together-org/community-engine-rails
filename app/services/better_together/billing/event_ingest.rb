# frozen_string_literal: true

module BetterTogether
  module Billing
    # Records a processor event once. A duplicate delivery returns the existing row
    # with created: false, so the caller does not enqueue a second run.
    class EventIngest
      Ingested = Struct.new(:event, :created, keyword_init: true)

      def self.call(...) = new.call(...)

      def call(processor:, event_id:, event_type:, payload:)
        key = { processor: processor.to_s, event_id: event_id.to_s }
        existing = BetterTogether::Billing::Event.find_by(key)
        return Ingested.new(event: existing, created: false) if existing

        create_event(key, event_type, payload)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        raced = BetterTogether::Billing::Event.find_by(key)
        raise unless raced

        Ingested.new(event: raced, created: false)
      end

      private

      def create_event(key, event_type, payload)
        event = BetterTogether::Billing::Event.create!(**key, event_type:, payload: payload.to_h, first_received_at: Time.current)
        Ingested.new(event:, created: true)
      end
    end
  end
end
