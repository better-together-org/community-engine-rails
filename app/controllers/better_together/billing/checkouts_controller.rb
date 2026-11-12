# frozen_string_literal: true

module BetterTogether
  module Billing
    # A person buys a plan: choose how to pay, read and accept the agreements that apply, then
    # place the order. It lands on the order, waiting for payment.
    #
    # The agreements come first and are enforced here and again when the order is placed, so
    # nothing the screen does can skip them. If the platform's purchase agreements are missing or
    # still drafts the page says it cannot be completed yet and offers no way to accept.
    class CheckoutsController < ApplicationController # rubocop:disable Metrics/ClassLength
      include OwnerScoped
      include CheckoutTaxPreview

      before_action :set_plan
      before_action :set_add_ons
      before_action :set_choices
      after_action :verify_authorized

      def new
        authorize BetterTogether::Billing::Order, :checkout?
        load_choice
        @gate = build_gate if @method || @free_order
        load_billing_details
      end

      def create
        authorize BetterTogether::Billing::Order, :checkout?
        load_choice
        return render_again(:method_not_available) unless @method || @free_order
        return render_again(@address_error) unless address_ok?
        return render_again(:parts_too_large) if parts_too_large?

        @gate = build_gate
        return render_again(:not_ready) unless @gate.ready?
        return render_again(:accept_all) unless accepted_everything_missing?

        place_order
      end

      private

      def load_choice
        @method = chosen_method
        @parts = chosen_parts
        @renew_with = chosen_renewal_method
      end

      # An order that costs nothing has no tax to work out, so it asks for no billing address either.
      def load_billing_details
        return if @free_order

        load_addresses
        load_tax_preview
      end

      def load_addresses
        options = Checkout::BillingAddressOptions.new(platform: billing_owner, person: current_user.person,
                                                      selected_id: @address&.id || params[:billing_address_id])
        @addresses = options.addresses
        @selected_address_id = options.selected_id
        @new_address = @refused_address || options.blank_address
      end

      def platform_plans = billing_owner.billing_plans.sold_by_platform

      # The plan being bought: a primary plan, or an add-on the buyer may buy on its own because they hold a plan it extends.
      def set_plan
        @plan = platform_plans.active.find(params[:plan_id])
        render_not_found unless @plan.add_on? ? policy(@plan).buy_alone? : policy(@plan).purchase?
      end

      # The extras offered on this plan's order, and the ones the buyer ticked.
      def set_add_ons
        @available_add_ons = offered_add_ons
        chosen = Array(params[:add_on_ids]).map(&:to_s)
        @add_ons = @available_add_ons.select { |add_on| chosen.include?(add_on.id) }
        @purchasables = [@plan, *@add_ons]
        @order_cents = @purchasables.sum(&:amount_cents)
        @free_order = @purchasables.all?(&:free?)
      end

      # Only add-ons this buyer may buy, in the plan's currency.
      def offered_add_ons
        return [] if @plan.add_on?

        platform_plans.active.add_ons_for(@plan).where(currency: @plan.currency).order(:amount_cents, :identifier)
                      .select { |add_on| policy(add_on).purchase? }
      end

      def set_choices
        @purpose = Checkout::Methods.new(platform: billing_owner, plan: @plan).purpose
        @choices = Checkout::Methods.call(platform: billing_owner, plan: @plan, buyer: current_user.person, add_ons: @add_ons)
      end

      # Only a method this plan offers and the platform has switched on.
      def chosen_method
        return if @free_order

        @choices.find { |choice| choice.available? && choice.name == params[:payment_method].to_s }&.name
      end

      def build_gate
        Checkout::AgreementGate.new(platform: billing_owner, purpose: @purpose, signer: current_user.person, purchasables: @purchasables,
                                    payment_method: [@method, *@parts.map { |part| part[:payment_method] }].compact)
      end

      # The parts the buyer asked to pay now, by ways other than the one that takes the rest: an amount beside each. Only the
      # ways this plan offers, only positive amounts.
      def chosen_parts
        @choices.filter_map do |choice|
          next if !choice.available? || choice.name == @method

          cents = part_cents(choice.name)
          { payment_method: choice.name, amount_cents: cents } if cents.positive?
        end
      end

      def part_cents(name)
        value = params.dig(:part_amounts, name)
        value.present? ? Currency.to_minor(value, @plan.currency).to_i : 0
      end

      def parts_cents = @parts.sum { |part| part[:amount_cents] }

      # What each renewal of a subscription is paid by: one of the ways this plan offers that the platform settles itself.
      def chosen_renewal_method
        return unless @purpose == 'subscription'

        @choices.find { |choice| choice.renewable? && choice.name == params[:renew_with].to_s }&.name
      end

      # Every agreement still missing has its box ticked. Anything the buyer already accepted in its
      # current form needs no tick. The boxes and their names are the shared agreement mechanism's.
      def accepted_everything_missing?
        @gate.missing.all? { |agreement| params[helpers.agreement_acceptance_param_name(agreement)] == '1' }
      end

      def place_order
        @gate.accept!(method: 'checkout', context: { request: })
        order = Orders::Place.call(platform: billing_owner, buyer: current_user.person, purpose: @purpose,
                                   line_items: @purchasables.map { |purchasable| { purchasable: } },
                                   renewal_payment_method: @renew_with, billing_address: @address, **how_to_pay)
        redirect_to billing_order_path(order, locale: I18n.locale), notice: t('better_together.billing.checkout.placed')
      rescue Orders::Place::Refused, Checkout::AgreementGate::NotReady => e
        Rails.logger.warn("[billing] checkout refused: #{e.class}")
        render_again(:refused)
      end

      def address_ok? = @free_order || choose_address

      # The buyer's billing address: one of theirs, or a new one typed in. Every order that costs something needs one with a chosen
      # country and state; a free one needs none.
      def choose_address
        result = Checkout::BillingAddressChoice.call(platform: billing_owner, person: current_user.person,
                                                     address_id: params[:billing_address_id], new_address: params[:billing_address],
                                                     make_default: params[:make_default_billing] == '1')
        @refused_address = result.address unless result.ok?
        @address_error = :"address_#{result.error}" unless result.ok?
        @address = result.address if result.ok?
      end

      # Parts asked for, with the chosen way taking the rest; or just the chosen way, which pays the whole of it.
      def how_to_pay
        return {} if @free_order
        return { payment_method: @method } if @parts.empty?

        { payments: [*@parts, { payment_method: @method }] }
      end

      def render_again(reason)
        @error = reason
        load_billing_details
        render :new, status: :unprocessable_content
      end
    end
  end
end
