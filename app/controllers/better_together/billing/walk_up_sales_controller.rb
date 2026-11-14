# frozen_string_literal: true

module BetterTogether
  module Billing
    # A sale made in person. The seller picks what was sold, how it was paid and who bought it,
    # says the buyer accepted the agreements with them, and, if the money has changed hands,
    # that it has. The buyer does nothing and is told afterwards.
    class WalkUpSalesController < ApplicationController
      include OwnerScoped
      include PersonLookup

      ADDRESS_KEYS = OfflinePayments::WalkUp::ADDRESS_FIELDS.map(&:to_sym).freeze

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
        refuse(e)
      end

      private

      # Show the form again with what was typed, so the seller corrects it instead of starting over.
      def refuse(error)
        Rails.logger.warn("[billing] walk-up sale refused: #{error.class}")
        @error = error.try(:reason) || :refused
        @buyer = find_platform_person(params[:buyer_id].to_s.strip)
        @entered = entered_details
        render :new, status: :unprocessable_content
      end

      def chosen_plan
        @plans.find { |plan| plan.id == params[:plan_id] } || raise(ActiveRecord::RecordNotFound)
      end

      def set_choices
        @plans = billing_owner.billing_plans.sold_by_platform.active.sort_by { |plan| plan.name.to_s.downcase }
        @methods = offline_methods
      end

      def offline_methods
        billing_owner.billing_processor_settings.sold_by_platform.enabled.pluck(:processor)
      end

      def sale_attributes
        { platform: billing_owner, seller: current_user.person, plan: chosen_plan, buyer: buyer,
          payment_method: params[:payment_method].to_s, agreements_accepted: params[:agreements_accepted] == '1',
          payment_received: params[:payment_received] == '1' }.merge(buyer_details)
      end

      def buyer_details
        { buyer_name: params[:buyer_name].to_s, buyer_email: params[:buyer_email].to_s, billing_address: address_params }
      end

      def address_params = params.fetch(:billing_address, {}).permit(*ADDRESS_KEYS).to_h

      # What the seller typed, shown again when the sale is refused.
      def entered_details = params.permit(:buyer_name, :buyer_email).to_h.merge('billing_address' => address_params)

      # Someone who belongs to this platform, picked from the person select (see PeopleController). None picked means
      # a new buyer, made from the name and email given; a pick that is not on this platform is refused.
      def buyer
        picked = params[:buyer_id].to_s.strip
        return if picked.blank?

        find_platform_person(picked) || raise(OfflinePayments::WalkUp::Refused, 'unknown buyer')
      end
    end
  end
end
