# frozen_string_literal: true

module BetterTogether
  module Billing
    # A sale made in person. The seller picks what was sold, how it was paid and who bought it,
    # says the buyer accepted the agreements with them, and, if the money has changed hands,
    # that it has. The buyer does nothing and is told afterwards.
    class WalkUpSalesController < ApplicationController
      include OwnerScoped

      before_action :set_choices
      after_action :verify_authorized

      def new
        authorize BetterTogether::Billing::Order, :walk_up?
      end

      def create
        authorize BetterTogether::Billing::Order, :walk_up?
        order = OfflinePayments::WalkUp.call(**sale_attributes)
        redirect_to billing_sale_path(order, locale: I18n.locale), notice: t('better_together.billing.walk_up.placed')
      rescue OfflinePayments::WalkUp::Refused, OfflinePayments::Transition::Refused => e
        Rails.logger.warn("[billing] walk-up sale refused: #{e.class}")
        @error = :refused
        render :new, status: :unprocessable_content
      end

      private

      def set_choices
        @plans = billing_owner.billing_plans.sold_by_platform.active.order(:name)
        @methods = offline_methods
      end

      def offline_methods
        billing_owner.billing_processor_settings.sold_by_platform.enabled.pluck(:processor)
      end

      def sale_attributes
        { platform: billing_owner, seller: current_user.person, buyer: buyer, plan: @plans.find(params[:plan_id]),
          payment_method: params[:payment_method].to_s, agreements_accepted: params[:agreements_accepted] == '1',
          payment_received: params[:payment_received] == '1' }
      end

      # Someone who belongs to this platform, found by their exact handle: no searching through members.
      def buyer
        person = BetterTogether::Person.find_by(identifier: params[:buyer_identifier].to_s.strip)
        member = person && BetterTogether::PersonPlatformMembership.active.exists?(member: person, joinable: billing_owner)
        member ? person : raise(OfflinePayments::WalkUp::Refused, 'unknown buyer')
      end
    end
  end
end
