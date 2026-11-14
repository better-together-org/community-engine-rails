# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # Writes the billing event for something that happened to an offline payment, so there is
      # always a record of who did what and when. The event carries identifiers and the neutral
      # outcome only: never a reference, a payee detail or a note.
      module Audit
        module_function

        def record(offline, event_type:, outcome_kind:, actor: nil)
          event_id = SecureRandom.uuid
          type = "#{offline.processor}.#{event_type}"
          offline.platform.billing_events.create!(
            processor: offline.processor, event_id:, event_type: type, processing_status: 'processed', processed_at: Time.current,
            outcome_kind: outcome_kind.to_s, subject: offline,
            payload: { 'id' => event_id, 'type' => type, 'outcome_kind' => outcome_kind.to_s, 'actor_id' => actor&.id,
                       'order_id' => offline.order_id, 'status' => offline.status }
          )
        end
      end
    end
  end
end
