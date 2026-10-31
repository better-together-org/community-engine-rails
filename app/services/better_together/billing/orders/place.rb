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
      # waiting for the seller to say the money arrived (see OfflinePayments::Open).
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

        # `lines` are hashes with `purchasable:` and an optional `quantity:`.
        def initialize(platform:, buyer:, purpose:, lines:, payment_method: nil, signer: nil, seller: nil, # rubocop:disable Metrics/ParameterLists
                       on_behalf_of: nil, subject: nil, hold_hours: nil, seller_assisted: false)
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
        end

        def call
          check_lines!
          raise AgreementsRequired, gate unless gate.satisfied?

          Order.transaction { open_for_payment(record_acceptances(build_order.tap(&:save!))) }
        rescue ActiveRecord::RecordInvalid => e
          raise Refused, e.record.errors.full_messages.to_sentence
        end

        private

        attr_reader :platform, :buyer, :signer, :payment_method, :purpose, :lines, :seller, :on_behalf_of, :subject, :seller_assisted

        def gate
          @gate ||= Checkout::AgreementGate.new(platform:, purpose:, signer:, seller:, purchasables:, payment_method:)
        end

        # The signer's acceptances are copied onto the order, so what applied to this purchase is
        # kept even if the agreements change or are accepted again later.
        def record_acceptances(order)
          gate.agreements.each { |agreement| OrderAgreementAcceptance.record!(order:, agreement:, signer:, on_behalf_of:) }
          order
        end

        def open_for_payment(order)
          reserve(order)
          order.update!(status: 'awaiting_payment', placed_at: Time.current, expires_at: hold_hours.hours.from_now)
          Settle.call(order) if order.total_cents.zero?
          OfflinePayments::Open.call(order:, setting: offline_setting, seller_assisted:) if offline_setting && order.total_cents.positive?
          Notifications.deliver('order_placed', subject: order)
          order
        end

        # The seller's own hold time for a method outside a vendor, else the default.
        def hold_hours = @hold_hours || offline_setting&.hold_hours || Order::DEFAULT_HOLD_HOURS

        # The switched-on setting for the chosen method, when it is one outside a vendor.
        def offline_setting
          return unless payment_method.present? && Billing.offline_method?(payment_method)

          @offline_setting ||= sellers_settings.enabled.find_by(processor: payment_method.to_s)
        end

        def sellers_settings
          seller ? platform.billing_processor_settings.sold_by(seller) : platform.billing_processor_settings.sold_by_platform
        end

        def check_lines!
          raise Refused, "that is not a kind of purchase: #{purpose}" unless Order::PURPOSES.include?(purpose)
          raise Refused, 'an order needs at least one line' if lines.empty?

          check_purchasables!
          check_payment_method!
        end

        def check_purchasables!
          purchasables.each { |purchasable| check_purchasable!(purchasable) }
          raise Refused, 'all lines must be in the same currency' if purchasables.map(&:purchasable_currency).uniq.size > 1
        end

        # A method outside a vendor works only when the seller switched it on for this kind of purchase.
        def check_payment_method!
          return unless payment_method.present? && Billing.offline_method?(payment_method)
          raise Refused, 'that way of paying is not available' unless offline_setting&.allows?(purpose)

          currencies = Billing.processor_adapter(payment_method).supported_currencies
          raise Refused, 'that way of paying does not work in that currency' if currencies && !currencies.include?(order_currency)
        end

        def order_currency = purchasables.first&.purchasable_currency

        def purchasables = @purchasables ||= lines.map { |line| line.fetch(:purchasable) }

        def check_purchasable!(purchasable)
          raise Refused, 'that cannot be bought' unless Purchasable.model_names.include?(purchasable.class.name)
          raise Refused, 'that is not for sale' unless purchasable.purchasable?
          raise Refused, 'that belongs to another platform' if purchasable.try(:platform_id) != platform.id
          raise Refused, 'that is sold by someone else' unless same_seller?(purchasable)
        end

        def same_seller?(purchasable)
          return seller.nil? if purchasable.try(:seller_id).blank?

          seller.present? && purchasable.seller_type == seller.class.name && purchasable.seller_id == seller.id
        end

        def build_order
          order = platform.billing_orders.build(buyer:, purpose:, seller:, on_behalf_of:, subject:,
                                                currency: purchasables.first.purchasable_currency, status: 'draft')
          lines.each_with_index { |line, index| order.lines.build(line_attributes(line, index)) }
          order
        end

        def line_attributes(line, index)
          purchasable = line.fetch(:purchasable)
          { platform_id: platform.id, position: index, purchasable:, quantity: line.fetch(:quantity, 1),
            description: purchasable.purchasable_description, unit_amount_cents: purchasable.purchasable_amount_cents,
            currency: purchasable.purchasable_currency }
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
