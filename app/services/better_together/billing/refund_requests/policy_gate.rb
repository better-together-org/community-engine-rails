# frozen_string_literal: true

module BetterTogether
  module Billing
    module RefundRequests
      # The platform's refund policy, an agreement a buyer reads and ticks before a refund request is sent. It is asked for
      # only once the platform has written it and set it active; a draft (the placeholder text) is never put in front of a buyer.
      # Once a buyer has accepted its current wording they are not asked again.
      class PolicyGate
        IDENTIFIER = 'refund_policy'

        def initialize(platform:, signer:)
          @platform = platform
          @signer = signer
        end

        def agreement
          return @agreement if defined?(@agreement)

          @agreement = Agreement.find_by(platform:, identifier: IDENTIFIER)
        end

        # Whether the platform has a policy in force.
        def required? = agreement.present? && agreement.lifecycle_state_active? && agreement.active_for_consent?

        # Whether the signer still has to accept it.
        def missing? = required? && !agreement.accepted_by?(signer)

        def accept!(context: {})
          return unless missing?

          AgreementAcceptanceRecorder.record!(agreement:, participant: signer, acceptance_method: 'agreement_review', context:)
        end

        private

        attr_reader :platform, :signer
      end
    end
  end
end
