# frozen_string_literal: true

module BetterTogether
  module Billing
    # A person buys a plan: choose how to pay, read and accept the agreements that apply, then
    # place the order. It lands on the order, waiting for payment.
    #
    # The agreements come first and are enforced here and again when the order is placed, so
    # nothing the screen does can skip them. If the platform's purchase agreements are missing or
    # still drafts the page says it cannot be completed yet and offers no way to accept.
    class CheckoutsController < ApplicationController
      include OwnerScoped

      before_action :set_plan
      before_action :set_choices
      after_action :verify_authorized

      def new
        authorize BetterTogether::Billing::Order, :checkout?
        @method = chosen_method
        @parts = chosen_parts
        @renew_with = chosen_renewal_method
        @gate = build_gate if @method
      end

      def create
        authorize BetterTogether::Billing::Order, :checkout?
        @method = chosen_method
        @parts = chosen_parts
        @renew_with = chosen_renewal_method
        return render_again(:method_not_available) unless @method
        return render_again(:parts_too_large) if parts_cents >= @plan.amount_cents && @parts.any?

        @gate = build_gate
        return render_again(:not_ready) unless @gate.ready?
        return render_again(:accept_all) unless accepted_everything_missing?

        place_order
      end

      private

      def platform_plans = billing_owner.billing_plans.sold_by_platform

      def set_plan
        @plan = platform_plans.active.find(params[:plan_id])
      end

      def set_choices
        @purpose = Checkout::Methods.new(platform: billing_owner, plan: @plan).purpose
        @choices = Checkout::Methods.call(platform: billing_owner, plan: @plan, buyer: current_user.person)
      end

      # Only a method this plan offers and the platform has switched on.
      def chosen_method
        @choices.find { |choice| choice.available? && choice.name == params[:payment_method].to_s }&.name
      end

      def build_gate
        Checkout::AgreementGate.new(platform: billing_owner, purpose: @purpose, signer: current_user.person, purchasables: [@plan],
                                    payment_method: [@method, *@parts.map { |part| part[:payment_method] }])
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
      # current form needs no tick.
      def accepted_everything_missing?
        ticked = Array(params[:accepted_agreement_ids]).map(&:to_s)
        @gate.missing.all? { |agreement| ticked.include?(agreement.id) }
      end

      def place_order
        @gate.accept!(method: 'checkout', context: { request: })
        order = Orders::Place.call(platform: billing_owner, buyer: current_user.person, purpose: @purpose, lines: [{ purchasable: @plan }],
                                   renewal_payment_method: @renew_with, **how_to_pay)
        redirect_to billing_order_path(order, locale: I18n.locale), notice: t('better_together.billing.checkout.placed')
      rescue Orders::Place::Refused, Checkout::AgreementGate::NotReady => e
        Rails.logger.warn("[billing] checkout refused: #{e.class}")
        render_again(:refused)
      end

      # Parts asked for, with the chosen way taking the rest; or just the chosen way, which pays the whole of it.
      def how_to_pay
        return { payment_method: @method } if @parts.empty?

        { payments: [*@parts, { payment_method: @method }] }
      end

      def render_again(reason)
        @error = reason
        render :new, status: :unprocessable_content
      end
    end
  end
end
