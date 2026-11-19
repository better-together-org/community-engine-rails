# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # A payer changes how later renewals of a subscription are paid, to another way its plan offers that Community
      # Engine settles itself and the platform has switched on. A period already invoiced keeps the method it was
      # invoiced with; the change applies from the next renewal.
      class ChangeMethod
        # Why a change was refused; `code` is a key under `subscriptions.method_change_refused`.
        class Refused < StandardError
          attr_reader :code

          def initialize(code)
            @code = code
            super(code.to_s)
          end
        end

        def self.call(term:, method:) = new(term).call(method)

        # The ways to renew by other than the current one.
        def self.options(term)
          return [] unless term.local?

          Checkout::Methods.call(platform: term.platform, plan: term.plan, buyer: term.payer)
                           .select { |choice| choice.renewable? && choice.name != term.payment_method }
        end

        def initialize(term)
          @term = term
        end

        def call(method) # rubocop:disable Metrics/AbcSize
          raise Refused, :not_local unless term.local?
          raise Refused, :unchanged if method.to_s == term.payment_method
          raise Refused, :not_offered unless self.class.options(term).any? { |choice| choice.name == method.to_s }

          # The method is fixed once a term exists; this service is the one way it moves.
          SubscriptionTerm.where(id: term.id).update_all(payment_method: method.to_s, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
          term.reload
        end

        private

        attr_reader :term
      end
    end
  end
end
