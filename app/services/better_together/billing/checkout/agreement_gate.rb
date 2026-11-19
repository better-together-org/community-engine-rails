# frozen_string_literal: true

module BetterTogether
  module Billing
    module Checkout
      # The check that stands between a buyer and a purchase: every agreement that applies must
      # exist, be in force, and have been accepted by the person signing, as it reads now.
      #
      # It fails closed. A platform whose purchase agreements are missing or still drafts cannot
      # sell, and neither can a buyer who has not accepted the current version.
      #
      #   gate = AgreementGate.new(platform:, purpose:, signer:, payment_method:, purchasables: [plan])
      #   gate.satisfied?   # can the order be placed?
      #   gate.missing      # what the buyer still has to accept
      #   gate.accept!      # records the buyer's acceptance of what is missing
      class AgreementGate
        Problem = Data.define(:code, :agreement)

        class NotReady < StandardError; end

        # `signer` is the person accepting; the purchase may be on behalf of a community or person.
        def initialize(platform:, purpose:, signer:, seller: nil, purchasables: [], payment_method: nil) # rubocop:disable Metrics/ParameterLists
          @platform = platform
          @signer = signer
          @resolution = AgreementResolver.call(platform:, purpose:, seller:, purchasables:, payment_method:)
        end

        attr_reader :resolution, :signer

        def agreements = resolution.agreements

        # What is wrong with the platform's set-up, whoever is buying.
        def problems
          @problems ||= begin
            list = agreements.reject { |agreement| in_force?(agreement) }.map { |agreement| Problem.new(code: :not_in_force, agreement:) }
            list.unshift(Problem.new(code: :no_agreement, agreement: nil)) unless resolution.base_terms?
            list
          end
        end

        def ready? = problems.empty?

        # The agreements the signer has not accepted in their current form.
        def missing = agreements.reject { |agreement| agreement.accepted_by?(signer) }

        def satisfied? = ready? && missing.empty?

        # Records the signer's acceptance of everything still missing. Refuses when the set-up is
        # not ready, so nobody is asked to accept a draft.
        def accept!(method: 'checkout', context: {})
          raise NotReady, problems.map(&:code).uniq.join(', ') unless ready?

          missing.each do |agreement|
            AgreementAcceptanceRecorder.record!(agreement:, participant: signer, acceptance_method: method, context:)
          end
          @problems = nil
          self
        end

        private

        def in_force?(agreement) = agreement.lifecycle_state_active? && agreement.active_for_consent?
      end
    end
  end
end
