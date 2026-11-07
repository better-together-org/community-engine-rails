# frozen_string_literal: true

module BetterTogether
  module Billing
    module Orders
      # Places an order: a draft with its lines, the purchasables held, then waiting for payment.
      #
      # Everything happens in one transaction, so a refusal part-way leaves nothing behind (and
      # nothing held). It refuses what could not be sold: no lines, a purchasable that is not
      # for sale or belongs to another platform or seller, or lines in different currencies.
      #
      # It also refuses until the purchase agreements are in order: every agreement that applies
      # must exist, be in force, and have been accepted by the `signer` (the buyer unless told
      # otherwise) as it reads now. The acceptance is copied onto the order as its evidence. This
      # is checked here, on the server, whatever the screens did.
      #
      # A method outside a vendor (cash, a cheque, an e-transfer) must also be switched on for the
      # seller and allowed for this kind of purchase and currency; then the order opens a payment
      # waiting for the seller to say the money arrived (see OfflinePayments::Open). Store credit is spent
      # in the same transaction and pays the whole order or the order is refused (see Credit::PayOrder).
      #
      #   Orders::Place.call(platform:, buyer:, purpose: 'one_time', payment_method: 'cash',
      #                      lines: [{ purchasable: plan }])
      class Place
        class Refused < StandardError; end

        # The agreements are not in order; `gate` says what is missing or not in force.
        class AgreementsRequired < Refused
          attr_reader :gate

          def initialize(gate)
            @gate = gate
            super('the purchase agreements have not been accepted')
          end
        end

        def self.call(...) = new(...).call

        # `lines` are hashes with `purchasable:`, an optional `quantity:` and an optional `unit_amount_cents:` (the price a
        # subscriber was sold at, when it differs from the plan's today). A renewal (`renewal: true`) may be for a
        # purchasable that is no longer for sale, and holds the order until `expires_at` instead of for a number of hours.
        def initialize(platform:, buyer:, purpose:, lines:, payment_method: nil, signer: nil, seller: nil, # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
                       on_behalf_of: nil, subject: nil, hold_hours: nil, seller_assisted: false, expires_at: nil, renewal: false,
                       payments: nil, renewal_payment_method: nil)
          @platform = platform
          @buyer = buyer
          @signer = signer || buyer
          @payment_method = payment_method
          @purpose = purpose.to_s
          @lines = Array(lines)
          @seller = seller
          @on_behalf_of = on_behalf_of
          @subject = subject
          @hold_hours = hold_hours
          @seller_assisted = seller_assisted
          @expires_at = expires_at
          @renewal = renewal
          @requested_parts = payments
          @renewal_payment_method = renewal_payment_method.presence
        end

        def call
          check_lines!
          raise AgreementsRequired, gate unless gate.satisfied?

          Order.transaction { open_for_payment(record_acceptances(build_order.tap(&:save!))) }
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :platform, :buyer, :signer, :payment_method, :purpose, :lines, :seller, :on_behalf_of, :subject, :seller_assisted, :renewal

        def gate
          @gate ||= Checkout::AgreementGate.new(platform:, purpose:, signer:, seller:, purchasables:,
                                                payment_method: parts.any? ? parts.methods_named : payment_method)
        end

        # The signer's acceptances are copied onto the order, so what applied to this purchase is
        # kept even if the agreements change or are accepted again later.
        def record_acceptances(order)
          gate.agreements.each { |agreement| OrderAgreementAcceptance.record!(order:, agreement:, signer:, on_behalf_of:) }
          order
        end

        def open_for_payment(order)
          reserve(order)
          order.update!(status: 'awaiting_payment', placed_at: Time.current, expires_at: @expires_at || hold_hours.hours.from_now)
          Settle.call(order) if order.total_cents.zero?
          open_payments(order)
          Notifications.deliver('order_placed', subject: order)
          order
        end

        def open_payments(order)
          return parts.open(order, seller_assisted:) if parts.any?

          OpenPayment.call(order:, choice: payment_choice, seller_assisted:)
        end

        # The seller's own hold time for a method outside a vendor, else the default.
        def hold_hours = @hold_hours || parts.hold_hours || payment_choice.offline_setting&.hold_hours || Order::DEFAULT_HOLD_HOURS

        # Several ways of paying, asked for together (see PaymentParts).
        def parts
          @parts ||= PaymentParts.new(@requested_parts, platform:, seller:, purpose:, currency: order_currency, total_cents: lines_total_cents)
        end

        def lines_total_cents
          lines.sum { |line| line.fetch(:unit_amount_cents, line.fetch(:purchasable).purchasable_amount_cents) * line.fetch(:quantity, 1) }
        end

        def payment_choice = @payment_choice ||= PaymentChoice.new(platform:, seller:, name: payment_method, purpose:, currency: order_currency)

        def check_lines!
          raise Refused, "that is not a kind of purchase: #{purpose}" unless Order::PURPOSES.include?(purpose)
          raise Refused, 'an order needs at least one line' if lines.empty?

          check_purchasables!
          check_payment_methods!
        end

        def check_payment_methods!
          problem = parts.any? ? parts.problem : payment_choice.problem
          raise Refused, problem if problem
          raise Refused, 'that is not a way of paying to renew by' unless renewal_method_usable?
        end

        # What a subscription renews by must be a method Community Engine settles itself, switched on for subscriptions.
        def renewal_method_usable?
          return true if @renewal_payment_method.blank?

          Billing.local_method?(@renewal_payment_method) && PaymentChoice.new(platform:, seller:, name: @renewal_payment_method, purpose:,
                                                                              currency: order_currency).problem.nil?
        end

        def check_purchasables!
          problem = LineProblem.new(platform:, seller:, renewal:).for(purchasables)
          raise Refused, problem if problem
        end

        def order_currency = purchasables.first&.purchasable_currency

        def purchasables = @purchasables ||= lines.map { |line| line.fetch(:purchasable) }

        def build_order
          order = platform.billing_orders.build(buyer:, purpose:, seller:, on_behalf_of:, subject:, status: 'draft',
                                                renewal_payment_method: @renewal_payment_method,
                                                currency: purchasables.first.purchasable_currency)
          lines.each_with_index { |line, index| order.lines.build(line_attributes(line, index)) }
          order
        end

        def line_attributes(line, index)
          purchasable = line.fetch(:purchasable)
          { platform_id: platform.id, position: index, purchasable:, quantity: line.fetch(:quantity, 1),
            description: purchasable.purchasable_description, currency: purchasable.purchasable_currency,
            unit_amount_cents: line.fetch(:unit_amount_cents, purchasable.purchasable_amount_cents) }
        end

        # Holds each purchasable for the order. If one refuses, the transaction rolls back and
        # whatever was held before it is released with it.
        def reserve(order)
          order.lines.each { |line| line.purchasable.reserve!(quantity: line.quantity) }
        rescue StandardError => e
          raise Refused, e.message
        end
      end
    end
  end
end
