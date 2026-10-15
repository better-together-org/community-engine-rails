# frozen_string_literal: true

module BetterTogether
  module Billing
    # What an adapter returns after processing one event.
    #   processed - state changed as intended
    #   ignored   - nothing relevant to this platform (not an error)
    #   alerted   - handled, but an operator should see it (e.g. a failed payment)
    #   retry     - a prerequisite is missing; try again shortly (retry_reason says why)
    class EventResult
      STATUSES = %i[processed ignored alerted retry].freeze

      attr_reader :status, :billable_owner, :beneficiary, :message, :retry_reason

      def initialize(status:, billable_owner: nil, beneficiary: nil, message: nil, retry_reason: nil)
        raise ArgumentError, "unknown status #{status.inspect}" unless STATUSES.include?(status.to_sym)

        @status = status.to_sym
        @billable_owner = billable_owner
        @beneficiary = beneficiary
        @message = message
        @retry_reason = retry_reason
      end

      def retry? = status == :retry
    end
  end
end
