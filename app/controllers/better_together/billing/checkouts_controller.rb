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
        @gate = build_gate if @method
      end

      def create
        authorize BetterTogether::Billing::Order, :checkout?
        @method = chosen_method
        return render_again(:method_not_available) unless @method

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
        @choices = Checkout::Methods.call(platform: billing_owner, plan: @plan)
        @purpose = Checkout::Methods.new(platform: billing_owner, plan: @plan).purpose
      end

      # Only a method this plan offers and the platform has switched on.
      def chosen_method
        @choices.find { |choice| choice.available? && choice.name == params[:payment_method].to_s }&.name
      end

      def build_gate
        Checkout::AgreementGate.new(platform: billing_owner, purpose: @purpose, signer: current_user.person, purchasables: [@plan],
                                    payment_method: @method)
      end

      # Every agreement still missing has its box ticked. Anything the buyer already accepted in its
      # current form needs no tick.
      def accepted_everything_missing?
        ticked = Array(params[:accepted_agreement_ids]).map(&:to_s)
        @gate.missing.all? { |agreement| ticked.include?(agreement.id) }
      end

      def place_order
        @gate.accept!(method: 'checkout', context: { request: })
        order = Orders::Place.call(platform: billing_owner, buyer: current_user.person, purpose: @purpose, payment_method: @method,
                                   lines: [{ purchasable: @plan }])
        redirect_to billing_order_path(order, locale: I18n.locale), notice: t('better_together.billing.checkout.placed')
      rescue Orders::Place::Refused, Checkout::AgreementGate::NotReady => e
        Rails.logger.warn("[billing] checkout refused: #{e.class}")
        render_again(:refused)
      end

      def render_again(reason)
        @error = reason
        render :new, status: :unprocessable_content
      end
    end
  end
end
