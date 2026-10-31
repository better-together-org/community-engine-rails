# frozen_string_literal: true

module BetterTogether
  module Billing
    # What an adapter returns after processing one event.
    #   processed - state changed as intended
    #   ignored   - nothing relevant to this platform (not an error)
    #   alerted   - handled, but an operator should see it (e.g. a failed payment)
    #   retry     - a prerequisite is missing; try again shortly (retry_reason says why)
    #
    # `outcome_kind` says what happened in processor-neutral terms (see OUTCOME_KINDS), and
    # `subject` is the record it happened to (a Billing::Subjectable model). Notifications
    # and reports key off these, so a processor's own event names never leave its adapter.
    # Both are optional: an event that matters to nobody (an ignored one) has neither.
    class EventResult
      STATUSES = %i[processed ignored alerted retry].freeze

      # The shared vocabulary. Processor adapters report the first group; core's own
      # services (offline payments, credit) report the second.
      OUTCOME_KINDS = %i[
        payment_succeeded payment_failed payment_action_required refund_issued dispute_opened dispute_resolved
        subscription_renewing subscription_canceled trial_ending trial_ended
        payment_claimed payment_confirmed payment_rejected payment_expired cheque_received cheque_cleared cheque_bounced
        refund_recorded settings_changed
      ].freeze

      attr_reader :status, :billable_owner, :beneficiary, :message, :retry_reason, :outcome_kind, :subject

      def initialize(status:, billable_owner: nil, beneficiary: nil, message: nil, retry_reason: nil, outcome_kind: nil, subject: nil) # rubocop:disable Metrics/ParameterLists
        raise ArgumentError, "unknown status #{status.inspect}" unless STATUSES.include?(status.to_sym)
        if outcome_kind && !OUTCOME_KINDS.include?(outcome_kind.to_sym)
          raise ArgumentError, "unknown outcome_kind #{outcome_kind.inspect}"
        end

        @status = status.to_sym
        @billable_owner = billable_owner
        @beneficiary = beneficiary
        @message = message
        @retry_reason = retry_reason
        @outcome_kind = outcome_kind&.to_sym
        @subject = subject
      end

      def retry? = status == :retry
    end
  end
end
