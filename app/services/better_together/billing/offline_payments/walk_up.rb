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
      #
      # The buyer is an existing person (`buyer:`) or, when they are not on the platform yet, a name given as
      # `buyer_name:` (see NewBuyer; they are invited to the community afterwards). Either way `buyer_email:` is
      # required: it is where the buyer's billing notices go for this order. A billing address may be given; it is
      # kept on the order, and on the person too when they have no address yet.
      class WalkUp
        class Refused < StandardError; end

        def self.call(...) = new(...).call

        ADDRESS_FIELDS = %w[line1 line2 city_name state_province_name postal_code country_name country_id state_id settlement_id].freeze
        ADDRESS_NAMES = %w[line1 line2 city_name state_province_name postal_code country_name].freeze
        ADDRESS_REQUIRED = %w[line1 city_name country_name].freeze

        def initialize(platform:, seller:, plan:, payment_method:, agreements_accepted:, buyer_email:, buyer: nil, buyer_name: nil, # rubocop:disable Metrics/ParameterLists
                       billing_address: nil, payment_received: false)
          @platform = platform
          @seller = seller
          @buyer = buyer
          @buyer_name = buyer_name
          @buyer_email = buyer_email.to_s.strip.downcase
          @address = build_address(billing_address)
          @billing_address = snapshot(@address)
          @invitation = nil
          @plan = plan
          @payment_method = payment_method.to_s
          @agreements_accepted = agreements_accepted
          @payment_received = payment_received
        end

        def call
          raise Refused, 'the buyer has to accept the agreements first' unless agreements_accepted
          raise Refused, 'that way of paying is not available' unless method_available?

          check_buyer_details!
          check_address!
          order = Order.transaction { sell }
          send_invitation
          order
        rescue NewBuyer::Invalid, Orders::Place::Refused, Checkout::AgreementGate::NotReady => e
          raise Refused, e.message
        end

        private

        attr_reader :platform, :seller, :plan, :buyer, :buyer_name, :buyer_email, :billing_address, :payment_method,
                    :agreements_accepted, :payment_received

        def sell
          @buyer ||= new_buyer
          record_in_person_acceptance
          order = place
          keep_address_on_person
          Transition.receive(order.offline_payments.first, by: seller) if payment_received && order.offline_payments.any?
          order
        end

        def check_buyer_details!
          raise Refused, 'the buyer needs an email address for their notices' unless buyer_email.match?(URI::MailTo::EMAIL_REGEXP)
          raise Refused, 'a buyer who is not on the platform needs a name' if @buyer.nil? && @buyer_name.to_s.strip.blank?
          raise Refused, 'the billing address is incomplete' unless address_complete?
        end

        def address_complete?
          billing_address.blank? || ADDRESS_REQUIRED.none? { |key| billing_address[key].blank? }
        end

        # The address goes through the same model as the address form, so a chosen country, state or settlement is
        # checked against the others and its name is copied into the text columns.
        def check_address!
          return if @address.nil? || @address.valid?

          raise Refused, "the billing address is not consistent: #{@address.errors.full_messages.to_sentence}"
        end

        def new_buyer
          result = NewBuyer.call(platform:, inviter: seller, name: buyer_name, email: buyer_email)
          @invitation = result.invitation
          result.person
        end

        # Queued once the sale is saved, so a refused sale invites no one.
        def send_invitation
          return unless @invitation

          CommunityInvitationsMailer.with(invitation: @invitation).invite.deliver_later
          @invitation.update_column(:last_sent, Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
        end

        # The address given at the sale is theirs to keep: saved on the person when they have none yet.
        def keep_address_on_person
          return if @address.nil? || buyer.addresses.exists?

          detail = buyer.contact_detail || buyer.create_contact_detail!
          @address.contact_detail = detail
          @address.save!
        end

        def build_address(address)
          values = (address || {}).to_h.stringify_keys.slice(*ADDRESS_FIELDS).transform_values { |value| value.to_s.strip }
          return if values.values.all?(&:blank?)

          Address.new(values.merge('label' => 'billing', 'postal' => true, 'physical' => false, 'primary_flag' => true))
        end

        # What the order keeps: the text as the address form would save it, plus which records were chosen. Built before
        # validation, so the chosen records' names are filled in here the way the model would.
        def snapshot(record)
          return {} unless record

          record.valid?
          record.attributes.slice(*ADDRESS_NAMES, 'country_id', 'state_id', 'settlement_id').compact_blank
        end

        def purpose = @purpose ||= Checkout::Methods.new(platform:, plan:).purpose

        # A sale in person is paid by something the seller can confirm; store credit is the buyer's to spend.
        def method_available?
          Billing.manual_method?(payment_method) &&
            Checkout::Methods.call(platform:, plan:).any? { |choice| choice.available? && choice.name == payment_method }
        end

        def record_in_person_acceptance
          gate = Checkout::AgreementGate.new(platform:, purpose:, signer: buyer, purchasables: [plan], payment_method:)
          gate.accept!(method: 'seller_assisted', context: { recorded_by_person_id: seller.id })
        end

        def place
          Orders::Place.call(platform:, buyer:, purpose:, payment_method:, line_items: [{ purchasable: plan }], seller_assisted: true,
                             details: { buyer_email:, billing_address: }, tax_address:)
        end

        # Where the buyer is, for tax; see TaxAddress.
        def tax_address = TaxAddress.call(@address, billing_address)
      end
    end
  end
end
