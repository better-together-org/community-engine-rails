# frozen_string_literal: true

module BetterTogether
  module Billing
    module OfflinePayments
      # A sale made in person: the seller places the order for the buyer, records that the buyer
      # accepted the purchase agreements with them, and, if the money has already changed hands,
      # confirms it. The buyer has to do nothing.
      #
      # The agreements are still required: the seller says the buyer accepted them in person, and that
      # is recorded as accepted in person (`seller_assisted`) with who recorded it, so it is never
      # mistaken for the buyer's own acceptance at checkout.
      class WalkUp
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        def initialize(platform:, seller:, buyer:, plan:, payment_method:, agreements_accepted:, payment_received: false) # rubocop:disable Metrics/ParameterLists
          @platform = platform
          @seller = seller
          @buyer = buyer
          @plan = plan
          @payment_method = payment_method.to_s
          @agreements_accepted = agreements_accepted
          @payment_received = payment_received
        end

        def call
          raise Refused, 'the buyer has to accept the agreements first' unless agreements_accepted
          raise Refused, 'that way of paying is not available' unless method_available?

          Order.transaction do
            record_in_person_acceptance
            order = place
            Transition.receive(order.offline_payments.first, by: seller) if payment_received && order.offline_payments.any?
            order
          end
        rescue Orders::Place::Refused, Checkout::AgreementGate::NotReady => e
          raise Refused, e.message
        end

        private

        attr_reader :platform, :seller, :buyer, :plan, :payment_method, :agreements_accepted, :payment_received

        def purpose = @purpose ||= Checkout::Methods.new(platform:, plan:).purpose

        def method_available?
          Checkout::Methods.call(platform:, plan:).any? { |choice| choice.available? && choice.name == payment_method }
        end

        def record_in_person_acceptance
          gate = Checkout::AgreementGate.new(platform:, purpose:, signer: buyer, purchasables: [plan], payment_method:)
          gate.accept!(method: 'seller_assisted', context: { recorded_by_person_id: seller.id })
        end

        def place
          Orders::Place.call(platform:, buyer:, purpose:, payment_method:, lines: [{ purchasable: plan }], seller_assisted: true)
        end
      end
    end
  end
end
